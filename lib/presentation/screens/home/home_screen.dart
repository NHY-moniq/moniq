import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/core/utils/color_utils.dart';
import 'package:moniq/data/datasources/device_calendar_data_source.dart';
import 'package:moniq/data/datasources/personal_event_local_data_source.dart';
import 'package:moniq/data/datasources/personal_note_local_data_source.dart';
import 'package:moniq/data/datasources/personal_shift_type_local_data_source.dart';
import 'package:moniq/data/models/shift_with_type.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/home_viewmodel.dart';
import 'package:moniq/presentation/widgets/calendar/moniq_calendar.dart';
import 'package:moniq/presentation/widgets/calendar/shift_marker.dart';
import 'package:moniq/presentation/widgets/calendar/today_card.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';
import 'package:table_calendar/table_calendar.dart';

// ── Providers ──

/// 이벤트/노트 변경 시 증가시켜 모든 관련 provider를 갱신하는 트리거
final eventRefreshProvider = StateProvider<int>((ref) => 0);

/// 날짜별 접기/펼치기 상태 (기본 펼침)
final dateExpandedProvider = StateProvider.family<bool, DateTime>((ref, date) => true);

final personalNoteDataSourceProvider = Provider<PersonalNoteLocalDataSource>(
  (ref) => PersonalNoteLocalDataSource(prefs: ref.watch(sharedPreferencesProvider)),
);

final personalEventDataSourceProvider = Provider<PersonalEventLocalDataSource>(
  (ref) => PersonalEventLocalDataSource(prefs: ref.watch(sharedPreferencesProvider)),
);

final personalShiftTypeDataSourceProvider =
    Provider<PersonalShiftTypeLocalDataSource>(
  (ref) => PersonalShiftTypeLocalDataSource(prefs: ref.watch(sharedPreferencesProvider)),
);

final personalShiftTypesProvider = Provider<List<PersonalShiftType>>(
  (ref) => ref.watch(personalShiftTypeDataSourceProvider).getAll(),
);

final monthlyNotesProvider =
    Provider.family<Map<DateTime, List<PersonalNote>>, DateTime>(
  (ref, month) {
    ref.watch(eventRefreshProvider);
    return ref.watch(personalNoteDataSourceProvider).getMonthlyNotes(month);
  },
);

final dateNotesProvider =
    Provider.family<List<PersonalNote>, DateTime>(
  (ref, date) {
    ref.watch(eventRefreshProvider);
    return ref.watch(personalNoteDataSourceProvider).getNotes(date);
  },
);

final monthlyEventsProvider =
    Provider.family<Map<DateTime, List<PersonalEvent>>, DateTime>(
  (ref, month) {
    ref.watch(eventRefreshProvider);
    return ref.watch(personalEventDataSourceProvider).getMonthlyEvents(month);
  },
);

final dateEventsProvider =
    Provider.family<List<PersonalEvent>, DateTime>(
  (ref, date) {
    ref.watch(eventRefreshProvider);
    return ref.watch(personalEventDataSourceProvider).getEvents(date);
  },
);

// ── Screen ──

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(homeViewModelProvider);
    final calendarStartDay = ref.watch(calendarStartDayProvider);
    final startingDay = calendarStartDay == 'sunday'
        ? StartingDayOfWeek.sunday
        : StartingDayOfWeek.monday;

    final currentUser = ref.watch(authRepositoryProvider).currentUser;
    final userMeta = currentUser?.userMetadata;
    final displayName = userMeta?['display_name'] as String?;
    final avatarUrl = userMeta?['avatar_url'] as String?;

    Widget buildAppBarTitle() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? () {
                    showDialog(
                      context: context,
                      builder: (ctx) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: CircleAvatar(
                            radius: 100,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            backgroundImage: CachedNetworkImageProvider(avatarUrl),
                          ),
                        ),
                      ),
                    );
                  }
                : null,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Icon(Icons.person, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant)
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            displayName != null && displayName.isNotEmpty
                ? '$displayName 님의 일정'
                : '내 일정',
          ),
        ],
      );
    }

    return calendarAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: buildAppBarTitle()),
        body: const MoniqLoadingView(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: buildAppBarTitle()),
        body: MoniqErrorView(
          message: '일정을 불러올 수 없습니다',
          onRetry: () => ref.read(homeViewModelProvider.notifier).refresh(),
        ),
      ),
      data: (state) {
        final today = DateTime.now();
        final todayKey = DateTime(today.year, today.month, today.day);
        final todayShifts = state.monthlyShifts[todayKey];
        final firstTodayShift =
            todayShifts != null && todayShifts.isNotEmpty ? todayShifts.first : null;

        final monthlyNotes =
            ref.watch(monthlyNotesProvider(state.focusedMonth));
        final monthlyEvents =
            ref.watch(monthlyEventsProvider(state.focusedMonth));
        final dateNotes =
            ref.watch(dateNotesProvider(state.selectedDate));
        final dateEvents =
            ref.watch(dateEventsProvider(state.selectedDate));


        return Scaffold(
          appBar: AppBar(
            title: buildAppBarTitle(),
            actions: [
              Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                ),
              ),
            ],
          ),
          endDrawer: _HomeDrawer(
            onImportCalendar: () => _importDeviceCalendar(context, ref),
            onExportCalendar: () => _exportCalendar(context, ref, state),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddMenu(context, ref, state.selectedDate),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 3,
            child: const Icon(Icons.add),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoniqCalendar(
                  focusedDay: state.focusedMonth,
                  selectedDay: state.selectedDate,
                  startingDayOfWeek: startingDay,
                  rowHeight: 68,
                  onDaySelected: (selected, focused) {
                    ref.read(homeViewModelProvider.notifier).selectDate(selected);
                  },
                  onPageChanged: (focused) {
                    ref.read(homeViewModelProvider.notifier).changeMonth(focused);
                  },
                  eventLoader: (day) {
                    final key = DateTime(day.year, day.month, day.day);
                    return [
                      ...state.monthlyShifts[key] ?? [],
                      ...monthlyEvents[key] ?? [],
                      ...monthlyNotes[key] ?? [],
                    ];
                  },
                  markerBuilder: (context, day, events) {
                    if (events.isEmpty) return null;
                    final markers = <Widget>[];
                    for (final s in events.whereType<ShiftWithType>().take(2)) {
                      markers.add(ShiftMarker(color: parseHexColor(s.shiftType.color)));
                    }
                    if (events.whereType<PersonalEvent>().isNotEmpty) {
                      markers.add(const ShiftMarker(color: AppColors.success));
                    }
                    if (events.whereType<PersonalNote>().isNotEmpty) {
                      markers.add(const ShiftMarker(color: AppColors.tertiary));
                    }
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: markers.take(4).toList(),
                    );
                  },
                  previewBuilder: (day) {
                    final key = DateTime(day.year, day.month, day.day);
                    final result = <CalendarPreview>[];
                    // 근무 최우선
                    final dayShifts = state.monthlyShifts[key];
                    if (dayShifts != null && dayShifts.isNotEmpty) {
                      final s = dayShifts.first;
                      result.add(CalendarPreview(
                        text: s.shiftType.name,
                        color: parseHexColor(s.shiftType.color),
                      ));
                    }
                    // 개인 일정
                    final evts = monthlyEvents[key];
                    if (evts != null && evts.isNotEmpty) {
                      final e = evts.first;
                      result.add(CalendarPreview(
                        text: e.title,
                        color: e.color != null ? parseHexColor(e.color!) : null,
                      ));
                    }
                    // 개인 일정이 2개 이상이면 2번째도 표시
                    if (result.length < 2 && evts != null && evts.length > 1) {
                      final e2 = evts[1];
                      result.add(CalendarPreview(
                        text: e2.title,
                        color: e2.color != null ? parseHexColor(e2.color!) : null,
                      ));
                    }
                    return result;
                  },
                ),

                if (firstTodayShift != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: AppSpacing.screenHorizontal,
                    child: TodayCard(
                      shiftTypeName: firstTodayShift.shiftType.name,
                      shiftTypeCode: firstTodayShift.shiftType.code,
                      shiftColor: parseHexColor(firstTodayShift.shiftType.color),
                      startTime: firstTodayShift.shiftType.startTime,
                      endTime: firstTodayShift.shiftType.endTime,
                      teamName: firstTodayShift.teamName,
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),
                _DateItemsPanel(
                  date: state.selectedDate,
                  shifts: state.selectedDateShifts ?? [],
                  events: dateEvents,
                  notes: dateNotes,
                ),

                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: AppSpacing.screenHorizontal,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        final today = DateTime.now();
                        final todayDate = DateTime(today.year, today.month, today.day);
                        ref.read(homeViewModelProvider.notifier).changeMonth(todayDate);
                        ref.read(homeViewModelProvider.notifier).selectDate(todayDate);
                      },
                      icon: const Icon(Icons.today, size: 18),
                      label: const Text('오늘로 이동'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.huge),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<File> _generateCalendarImage(HomeCalendarState state, WidgetRef ref) async {
    final focusedMonth = state.focusedMonth;
    final eventDs = ref.read(personalEventDataSourceProvider);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.white;

    const width = 800.0;
    const headerH = 60.0;
    const dayH = 24.0;
    const rowH = 50.0;
    final rows = ((daysInMonth + DateTime(focusedMonth.year, focusedMonth.month, 1).weekday - 1) / 7).ceil();
    final height = headerH + dayH + (rows * rowH) + 20;

    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);

    final headerPaint = TextPainter(
      text: TextSpan(
        text: '${focusedMonth.year}년 ${focusedMonth.month}월',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    headerPaint.paint(canvas, Offset((width - headerPaint.width) / 2, 16));

    const days = ['월', '화', '수', '목', '금', '토', '일'];
    const cellW = width / 7;
    for (int i = 0; i < 7; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: days[i],
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: i == 6 ? Colors.red : (i == 5 ? Colors.blue : Colors.grey),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cellW * i + (cellW - tp.width) / 2, headerH));
    }

    final firstWeekday = DateTime(focusedMonth.year, focusedMonth.month, 1).weekday - 1;
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(focusedMonth.year, focusedMonth.month, d);
      final col = (firstWeekday + d - 1) % 7;
      final row = (firstWeekday + d - 1) ~/ 7;
      final x = cellW * col;
      final y = headerH + dayH + row * rowH;

      final dayPainter = TextPainter(
        text: TextSpan(
          text: '$d',
          style: TextStyle(
            fontSize: 13,
            color: col == 6 ? Colors.red : (col == 5 ? Colors.blue : Colors.black87),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dayPainter.paint(canvas, Offset(x + 4, y + 2));

      final events = eventDs.getEvents(date);
      final shifts = state.monthlyShifts[date];
      if (shifts != null && shifts.isNotEmpty) {
        final sp = TextPainter(
          text: TextSpan(
            text: shifts.first.shiftType.name,
            style: const TextStyle(fontSize: 9, color: Colors.deepOrange),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        sp.paint(canvas, Offset(x + 4, y + 18));
      } else if (events.isNotEmpty) {
        final ep = TextPainter(
          text: TextSpan(
            text: events.first.title,
            style: const TextStyle(fontSize: 9, color: Colors.green),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1, ellipsis: '..',
        )..layout(maxWidth: cellW - 8);
        ep.paint(canvas, Offset(x + 4, y + 18));
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/moniq_${focusedMonth.year}_${focusedMonth.month}.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _exportCalendar(BuildContext context, WidgetRef ref, HomeCalendarState state) async {
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('내보내기 형식 선택'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'album'),
            child: const ListTile(
              leading: Icon(Icons.photo_album_outlined, color: AppColors.primary),
              title: Text('앨범에 저장'),
              subtitle: Text('캘린더 이미지를 사진 앨범에 저장'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'share'),
            child: const ListTile(
              leading: Icon(Icons.share_outlined, color: AppColors.tertiary),
              title: Text('이미지 공유하기'),
              subtitle: Text('카카오톡, 메시지 등으로 캘린더 이미지 공유'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );

    if (format == null || !context.mounted) return;

    try {
      final file = await _generateCalendarImage(state, ref);
      final focusedMonth = state.focusedMonth;

      if (format == 'album') {
        final result = await ImageGallerySaverPlus.saveFile(file.path);
        if (context.mounted) {
          final success = result['isSuccess'] == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(success ? '앨범에 저장되었습니다' : '저장에 실패했습니다')),
          );
        }
      } else if (format == 'share') {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'Moniq ${focusedMonth.year}년 ${focusedMonth.month}월 일정',
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e')),
        );
      }
    }
  }

  Future<void> _importDeviceCalendar(BuildContext context, WidgetRef ref) async {
    // 캘린더 소스 선택 다이얼로그
    final source = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('가져올 캘린더 선택'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'device'),
            child: const ListTile(
              leading: Icon(Icons.calendar_month, color: AppColors.primary),
              title: Text('기본 캘린더'),
              subtitle: Text('iPhone 기본 캘린더에서 가져오기'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            child: ListTile(
              leading: Icon(Icons.event, color: Colors.grey),
              title: Text('Google 캘린더', style: TextStyle(color: Colors.grey)),
              subtitle: const Text('추후 지원 예정'),
              contentPadding: EdgeInsets.zero,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Google 캘린더 연동은 추후 지원 예정입니다')),
              );
            },
          ),
        ],
      ),
    );

    if (source != 'device' || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('캘린더에서 일정을 가져오는 중...'), duration: Duration(seconds: 1)),
    );

    try {
      final ds = ref.read(deviceCalendarDataSourceProvider);
      final granted = await ds.requestPermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('캘린더 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.')),
          );
        }
        return;
      }

      // 1년치 이벤트 가져오기
      final now = DateTime.now();
      final allEvents = <DeviceCalendarEvent>[];
      for (int i = 0; i < 12; i++) {
        final month = DateTime(now.year, now.month + i, 1);
        final monthEvents = await ds.getEventsForMonth(month);
        allEvents.addAll(monthEvents);
      }

      if (allEvents.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('신규로 추가할 일정이 없습니다')),
          );
        }
        return;
      }

      final events = allEvents;

      final eventDs = ref.read(personalEventDataSourceProvider);
      int imported = 0;

      for (final event in events) {
        final existing = eventDs.getEvents(event.date);
        final isDuplicate = existing.any((e) => e.title == event.title);

        if (!isDuplicate) {
          await eventDs.addEvent(PersonalEvent(
            date: event.date,
            title: event.title,
            startTime: event.startTime,
            endTime: event.endTime,
            description: event.calendarName,
            color: event.color ?? '#5A8BB5',
            createdAt: DateTime.now(),
          ));
          imported++;
        }
      }

      _refreshAll(ref, DateTime.now());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(imported > 0
                ? '$imported건의 일정을 가져왔습니다'
                : '신규로 추가할 일정이 없습니다 (이미 등록됨)'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _showAddMenu(BuildContext context, WidgetRef ref, DateTime date) {
    final shiftTypes = ref.read(personalShiftTypesProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 근무 일정 빠른 추가 (근무 유형 칩)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('근무 일정 추가',
                        style: Theme.of(ctx).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: shiftTypes.map((st) {
                        final color = parseHexColor(st.color);
                        return ActionChip(
                          avatar: CircleAvatar(
                            backgroundColor: color,
                            radius: 8,
                          ),
                          label: Text(st.name),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _addShiftEvent(ref, date, st);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const Divider(height: AppSpacing.xxl),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: AppRadius.borderRadiusMd,
                  ),
                  child: const Icon(Icons.event, color: AppColors.success),
                ),
                title: const Text('일정 추가'),
                subtitle: const Text('시간, 색상, 설명을 포함한 일정'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEventForm(context, ref, date, null, null);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.borderRadiusMd,
                  ),
                  child: const Icon(Icons.edit_note, color: AppColors.tertiary),
                ),
                title: const Text('메모 추가'),
                subtitle: const Text('간단한 텍스트 메모'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showNoteForm(context, ref, date, null, null);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 근무 유형으로 빠르게 일정 추가
  Future<void> _addShiftEvent(WidgetRef ref, DateTime date, PersonalShiftType st) async {
    final event = PersonalEvent(
      date: DateTime(date.year, date.month, date.day),
      title: st.name,
      startTime: st.startTime,
      endTime: st.endTime,
      color: st.color,
      createdAt: DateTime.now(),
    );
    final ds = ref.read(personalEventDataSourceProvider);
    await ds.addEvent(event);
    _refreshAll(ref, date);
  }

  static void _showEventForm(BuildContext context, WidgetRef ref,
      DateTime date, int? index, PersonalEvent? existing) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    TimeOfDay? startTime =
        existing?.startTime != null ? _parseTime(existing!.startTime!) : null;
    TimeOfDay? endTime =
        existing?.endTime != null ? _parseTime(existing!.endTime!) : null;
    String selectedColor = existing?.color ?? '#38A169';

    const colorOptions = [
      '#38A169', '#E8923A', '#5A8BB5', '#E53E3E', '#F0C040', '#A0AEC0',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  index == null ? '일정 추가' : '일정 수정',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: '일정 제목', prefixIcon: Icon(Icons.event)),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
                          );
                          if (picked != null) setSheetState(() => startTime = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '시작',
                            prefixIcon: Icon(Icons.access_time, size: 20),
                            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          ),
                          child: Text(startTime != null ? _formatTime(startTime!) : '종일'),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: endTime ?? TimeOfDay(hour: (startTime?.hour ?? 9) + 1, minute: startTime?.minute ?? 0),
                          );
                          if (picked != null) setSheetState(() => endTime = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '종료',
                            prefixIcon: Icon(Icons.access_time, size: 20),
                            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          ),
                          child: Text(endTime != null ? _formatTime(endTime!) : '-'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: colorOptions.map((hex) {
                    final isSelected = selectedColor == hex;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: GestureDetector(
                        onTap: () => setSheetState(() => selectedColor = hex),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? 36 : 32,
                          height: isSelected ? 36 : 32,
                          decoration: BoxDecoration(
                            color: parseHexColor(hex),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: AppColors.textPrimaryLight, width: 2.5)
                                : null,
                            boxShadow: isSelected
                                ? [BoxShadow(color: parseHexColor(hex).withValues(alpha: 0.4), blurRadius: 6)]
                                : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(hintText: '설명 (선택)', prefixIcon: Icon(Icons.notes)),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    final event = PersonalEvent(
                      date: DateTime(date.year, date.month, date.day),
                      title: title,
                      startTime: startTime != null ? _formatTime(startTime!) : null,
                      endTime: endTime != null ? _formatTime(endTime!) : null,
                      description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
                      color: selectedColor,
                      createdAt: DateTime.now(),
                    );
                    final ds = ref.read(personalEventDataSourceProvider);
                    if (index == null) {
                      await ds.addEvent(event);
                    } else {
                      await ds.updateEvent(date, index, event);
                    }
                    _refreshAll(ref, date);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(index == null ? '추가' : '저장'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showNoteForm(BuildContext context, WidgetRef ref,
      DateTime date, int? index, String? currentContent) {
    final controller = TextEditingController(text: currentContent ?? '');
    final hasText = ValueNotifier<bool>((currentContent ?? '').trim().isNotEmpty);
    controller.addListener(() {
      hasText.value = controller.text.trim().isNotEmpty;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              index == null ? '메모 추가' : '메모 수정',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: '메모를 입력하세요'),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.lg),
            ValueListenableBuilder<bool>(
              valueListenable: hasText,
              builder: (ctx, hasValue, _) => ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  showDialog(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      content: const Text('추가하실 메모를 입력해주세요.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  );
                  return;
                }
                final ds = ref.read(personalNoteDataSourceProvider);
                if (index == null) {
                  await ds.addNote(date, text);
                } else {
                  await ds.updateNote(date, index, text);
                }
                _refreshAll(ref, date);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: hasValue
                    ? Colors.white
                    : Theme.of(ctx).colorScheme.onPrimary.withValues(alpha: 0.3),
              ),
              child: Text(index == null ? '추가' : '저장'),
            ),
            ),
          ],
        ),
      ),
    );
  }

  static void _refreshAll(WidgetRef ref, DateTime date) {
    // 모든 이벤트/노트 provider 캐시를 한번에 갱신
    ref.read(eventRefreshProvider.notifier).state++;
  }

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  /// 수정 시 근무 유형 선택 가능한 편집 폼
  static void _showEventEditWithShiftTypes(BuildContext context, WidgetRef ref,
      DateTime date, int index, PersonalEvent existing) {
    final shiftTypes = ref.read(personalShiftTypesProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('근무 유형으로 변경',
                        style: Theme.of(ctx).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: shiftTypes.map((st) {
                        final color = parseHexColor(st.color);
                        final isSelected = existing.title == st.name &&
                            existing.color == st.color;
                        return ActionChip(
                          avatar: CircleAvatar(
                            backgroundColor: color, radius: 8),
                          label: Text(st.name),
                          backgroundColor: isSelected
                              ? color.withValues(alpha: 0.2)
                              : null,
                          side: isSelected
                              ? BorderSide(color: color, width: 1.5)
                              : null,
                          onPressed: () {
                            final ds = ref.read(personalEventDataSourceProvider);
                            final updated = PersonalEvent(
                              date: DateTime(date.year, date.month, date.day),
                              title: st.name,
                              startTime: st.startTime,
                              endTime: st.endTime,
                              color: st.color,
                              createdAt: DateTime.now(),
                            );
                            ds.updateEvent(date, index, updated);
                            _refreshAll(ref, date);
                            Navigator.pop(ctx);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const Divider(height: AppSpacing.xxl),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: AppRadius.borderRadiusMd,
                  ),
                  child: const Icon(Icons.edit, color: AppColors.success),
                ),
                title: const Text('상세 수정'),
                subtitle: const Text('제목, 시간, 색상, 설명 직접 편집'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEventForm(context, ref, date, index, existing);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 날짜 아이템 통합 패널 (브랜드 감성 UI) ──

class _DateItemsPanel extends ConsumerWidget {
  const _DateItemsPanel({
    required this.date,
    required this.shifts,
    required this.events,
    required this.notes,
  });

  final DateTime date;
  final List<ShiftWithType> shifts;
  final List<PersonalEvent> events;
  final List<PersonalNote> notes;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasItems = shifts.isNotEmpty || events.isNotEmpty || notes.isNotEmpty;
    final weekday = _weekdays[date.weekday - 1];
    final totalItems = shifts.length + events.length + notes.length;
    final dateKey = DateTime(date.year, date.month, date.day);
    final isExpanded = ref.watch(dateExpandedProvider(dateKey));

    return Padding(
      padding: AppSpacing.screenHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 헤더 — 브랜드 스타일 카드 (탭하면 접기/펼치기)
          GestureDetector(
            onTap: totalItems > 0 ? () => ref.read(dateExpandedProvider(dateKey).notifier).state = !isExpanded : null,
            child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.brandYellow.withValues(alpha: 0.15),
                  AppColors.brandOrange.withValues(alpha: 0.10),
                  AppColors.brandBlue.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: AppRadius.borderRadiusMd,
            ),
            child: Row(
              children: [
                // 날짜 원형 뱃지 (로고 캐릭터 느낌)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brandOrange, AppColors.brandYellow],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandOrange.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${date.month}월 ${date.day}일 $weekday요일',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasItems
                          ? [
                              if (shifts.isNotEmpty) '근무 ${shifts.length}건',
                              if (events.isNotEmpty) '일정 ${events.length}건',
                              if (notes.isNotEmpty) '메모 ${notes.length}건',
                            ].join(' · ')
                          : '등록된 항목이 없습니다',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                if (totalItems > 0) ...[
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondaryLight,
                  ),
                ],
              ],
            ),
          ),
          ),

          if (!hasItems) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Column(
                children: [
                  // 빈 상태 — 로고 캐릭터 스타일 이모티콘
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.brandBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '·  ·',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brandBlue.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '+ 버튼으로 일정이나 메모를 추가해보세요',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 근무 목록
          if (shifts.isNotEmpty && isExpanded) ...[
            const SizedBox(height: AppSpacing.md),
            ...shifts.map((s) {
              final shiftColor = parseHexColor(s.shiftType.color);
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: AppRadius.borderRadiusMd,
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        decoration: BoxDecoration(
                          color: shiftColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(AppRadius.md),
                            bottomLeft: Radius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm, vertical: 2),
                                decoration: BoxDecoration(
                                  color: shiftColor.withValues(alpha: 0.15),
                                  borderRadius: AppRadius.borderRadiusSm,
                                ),
                                child: Text(
                                  s.shiftType.code,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: shiftColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                s.shiftType.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (s.shiftType.startTime != null) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  '${s.shiftType.startTime} ~ ${s.shiftType.endTime ?? ''}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                              if (s.teamName != null) ...[
                                const Spacer(),
                                Text(
                                  s.teamName!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            // 근무 아래에 개인 일정 첫 1개 미리보기
            if (events.isNotEmpty)
              _buildEventPreviewCard(theme, events.first),
          ],

          // 일정 목록 (근무가 없을 때 전체 표시)
          if (events.isNotEmpty && shifts.isEmpty && isExpanded) ...[
            const SizedBox(height: AppSpacing.md),
            ...events.asMap().entries.map((entry) {
              final index = entry.key;
              final event = entry.value;
              final eventColor =
                  event.color != null ? parseHexColor(event.color!) : AppColors.success;
              return _buildEventCard(theme, ref, context, event, eventColor, index);
            }),
          ],

          // 근무가 있을 때 나머지 일정 (2번째부터)
          if (events.length > 1 && shifts.isNotEmpty && isExpanded) ...[
            const SizedBox(height: AppSpacing.md),
            ...events.asMap().entries.where((e) => e.key > 0).map((entry) {
              final index = entry.key;
              final event = entry.value;
              final eventColor =
                  event.color != null ? parseHexColor(event.color!) : AppColors.success;

              return _buildEventCard(theme, ref, context, event, eventColor, index);
            }),
          ],

          // 메모 목록
          if (notes.isNotEmpty && isExpanded) ...[
            if (events.isNotEmpty || shifts.isNotEmpty) const SizedBox(height: AppSpacing.xs),
            ...notes.asMap().entries.map((entry) {
              final index = entry.key;
              final note = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: AppRadius.borderRadiusMd,
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.tertiary,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(AppRadius.md),
                            bottomLeft: Radius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.tertiary.withValues(alpha: 0.12),
                                  borderRadius: AppRadius.borderRadiusSm,
                                ),
                                child: Text(
                                  '메모',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.tertiary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  note.content,
                                  style: theme.textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz,
                            size: 18, color: AppColors.textSecondaryLight),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('수정')),
                          const PopupMenuItem(value: 'delete', child: Text('삭제')),
                        ],
                        onSelected: (action) {
                          if (action == 'edit') {
                            HomeScreen._showNoteForm(
                                context, ref, date, index, note.content);
                          } else if (action == 'delete') {
                            _deleteNote(ref, index);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// 근무 아래 개인 일정 미리보기 카드 (1개)
  Widget _buildEventPreviewCard(ThemeData theme, PersonalEvent event) {
    final eventColor =
        event.color != null ? parseHexColor(event.color!) : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: eventColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderRadiusSm,
        border: Border.all(color: eventColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.event, size: 14, color: eventColor),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '${event.title}  ${event.timeRange}',
              style: TextStyle(
                fontSize: 12,
                color: eventColor,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 일정 카드 (전체 표시용)
  Widget _buildEventCard(ThemeData theme, WidgetRef ref, BuildContext context,
      PersonalEvent event, Color eventColor, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: AppRadius.borderRadiusMd,
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: eventColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.md),
                  bottomLeft: Radius.circular(AppRadius.md),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm, vertical: 2),
                          decoration: BoxDecoration(
                            color: eventColor.withValues(alpha: 0.12),
                            borderRadius: AppRadius.borderRadiusSm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time,
                                  size: 12, color: eventColor),
                              const SizedBox(width: 3),
                              Text(event.timeRange,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: eventColor)),
                            ],
                          ),
                        ),
                        if (event.description != null &&
                            event.description!.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(event.description!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondaryLight),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz,
                  size: 18, color: AppColors.textSecondaryLight),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('수정')),
                const PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
              onSelected: (action) {
                if (action == 'edit') {
                  HomeScreen._showEventEditWithShiftTypes(
                      context, ref, date, index, event);
                } else if (action == 'delete') {
                  _deleteEvent(ref, index);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEvent(WidgetRef ref, int index) async {
    final ds = ref.read(personalEventDataSourceProvider);
    await ds.removeEvent(date, index);
    HomeScreen._refreshAll(ref, date);
  }

  void _deleteNote(WidgetRef ref, int index) async {
    final ds = ref.read(personalNoteDataSourceProvider);
    await ds.removeNote(date, index);
    HomeScreen._refreshAll(ref, date);
  }
}

// ── 홈 드로어 ──

class _HomeDrawer extends HookConsumerWidget {
  const _HomeDrawer({
    required this.onImportCalendar,
    required this.onExportCalendar,
  });

  final VoidCallback onImportCalendar;
  final VoidCallback onExportCalendar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final shiftTypes = ref.watch(personalShiftTypesProvider);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppSpacing.screenAll,
              child: Text('메뉴', style: theme.textTheme.titleLarge),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('내 근무 유형 설정'),
              subtitle: Text('${shiftTypes.length}개 설정됨'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _showPersonalShiftTypeManager(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('외부 캘린더 일정 가져오기'),
              subtitle: const Text('외부 캘린더 설정'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                onImportCalendar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('캘린더 내보내기'),
              subtitle: const Text('이미지 또는 스프레드시트로 내보내기'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                onExportCalendar();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPersonalShiftTypeManager(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _PersonalShiftTypeSheet(),
    );
  }
}

class _PersonalShiftTypeSheet extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final shiftTypes = ref.watch(personalShiftTypesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // 핸들
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Text('근무 유형 설정',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddShiftTypeForm(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('추가'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: shiftTypes.length,
              itemBuilder: (context, index) {
                final st = shiftTypes[index];
                final color = parseHexColor(st.color);
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: AppRadius.borderRadiusSm,
                      ),
                      child: Center(
                        child: Text(st.code,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            )),
                      ),
                    ),
                    title: Text(st.name),
                    subtitle: st.startTime != null
                        ? Text('${st.startTime} ~ ${st.endTime ?? ''}')
                        : null,
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('수정')),
                        const PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                      onSelected: (action) {
                        if (action == 'edit') {
                          _showEditShiftTypeForm(context, ref, st);
                        } else if (action == 'delete') {
                          ref.read(personalShiftTypeDataSourceProvider).remove(st.id);
                          ref.invalidate(personalShiftTypesProvider);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddShiftTypeForm(BuildContext context, WidgetRef ref) {
    _showShiftTypeForm(context, ref, null);
  }

  void _showEditShiftTypeForm(
      BuildContext context, WidgetRef ref, PersonalShiftType existing) {
    _showShiftTypeForm(context, ref, existing);
  }

  void _showShiftTypeForm(
      BuildContext context, WidgetRef ref, PersonalShiftType? existing) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final codeController = TextEditingController(text: existing?.code ?? '');
    String? startTime = existing?.startTime;
    String? endTime = existing?.endTime;
    String selectedColor = existing?.color ?? '#E8923A';

    const colorOptions = [
      '#F0C040', '#E8923A', '#5A8BB5', '#E53E3E', '#38A169', '#A0AEC0',
      '#9F7AEA', '#ED64A6',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? '근무 유형 추가' : '근무 유형 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '이름 (예: 데이)'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: '코드 (예: D)'),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: startTime != null
                                ? _parseTime(startTime!)
                                : const TimeOfDay(hour: 7, minute: 0),
                          );
                          if (picked != null) {
                            setDialogState(() => startTime = _formatTime(picked));
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '시작',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                          ),
                          child: Text(startTime ?? '없음'),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: endTime != null
                                ? _parseTime(endTime!)
                                : const TimeOfDay(hour: 15, minute: 0),
                          );
                          if (picked != null) {
                            setDialogState(() => endTime = _formatTime(picked));
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '종료',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                          ),
                          child: Text(endTime ?? '없음'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: colorOptions.map((hex) {
                    final isSelected = selectedColor == hex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = hex),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: parseHexColor(hex),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: AppColors.textPrimaryLight, width: 2.5)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final code = codeController.text.trim();
                if (name.isEmpty || code.isEmpty) {
                  showDialog(
                    context: ctx,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('입력 오류'),
                      content: const Text('필수 항목을 입력해주세요.\n이름과 코드는 반드시 입력해야 합니다.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                final ds = ref.read(personalShiftTypeDataSourceProvider);
                final st = PersonalShiftType(
                  id: existing?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  code: code,
                  startTime: startTime,
                  endTime: endTime,
                  color: selectedColor,
                );

                if (existing == null) {
                  ds.add(st);
                } else {
                  ds.update(existing.id, st);
                }
                ref.invalidate(personalShiftTypesProvider);
                Navigator.pop(ctx);
              },
              child: Text(existing == null ? '추가' : '저장'),
            ),
          ],
        ),
      ),
    );
  }

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
