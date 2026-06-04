import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moniq/data/models/announcement_model.dart';
import 'package:moniq/data/providers/announcement_providers.dart';
import 'package:moniq/data/providers/auth_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/app_typography.dart';
import 'package:moniq/presentation/viewmodels/announcement_viewmodel.dart';
import 'package:moniq/presentation/widgets/announcement/announcement_author.dart';
import 'package:moniq/presentation/widgets/announcement/announcement_filter_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_bottom_sheet.dart';
import 'package:moniq/presentation/widgets/common/moniq_empty_state.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';

/// 팀 공지사항 화면 필터 — DropdownButton 대신 바텀시트로 선택.
enum _AnnouncementFilter { all, pinned }

/// 팀 공지사항 화면의 선택된 필터.
final _teamAnnouncementFilterProvider =
    StateProvider.autoDispose<_AnnouncementFilter>(
  (_) => _AnnouncementFilter.all,
);

class AnnouncementScreen extends HookConsumerWidget {
  const AnnouncementScreen({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync =
        ref.watch(teamAnnouncementsProvider(teamId));
    final filter = ref.watch(_teamAnnouncementFilterProvider);
    final pinnedIds = ref.watch(pinnedAnnouncementIdsProvider);

    return Scaffold(
      appBar: const MoniqAppBar(title: '공지사항'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('공지 작성'),
      ),
      body: announcementsAsync.when(
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '공지사항을 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(teamAnnouncementsProvider(teamId)),
        ),
        data: (announcements) {
          if (announcements.isEmpty) {
            return MoniqEmptyState.encouraging(
              title: '아직 등록된 공지가 없어요',
              message: '팀원들에게 전달할 공지를 작성해보세요',
            );
          }

          // 개인 핀 기준으로 정렬: 내가 고정한 것 먼저, 그 안에서도 최신순
          final sorted = [...announcements]..sort((a, b) {
              final aPinned = pinnedIds.contains(a.id) ? 0 : 1;
              final bPinned = pinnedIds.contains(b.id) ? 0 : 1;
              if (aPinned != bPinned) return aPinned - bPinned;
              final aDate = a.createdAt;
              final bDate = b.createdAt;
              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return bDate.compareTo(aDate);
            });

          final visible = filter == _AnnouncementFilter.pinned
              ? sorted.where((a) => pinnedIds.contains(a.id)).toList()
              : sorted;

          return Column(
            children: [
              _AnnouncementFilterBar(
                filter: filter,
                onTap: () => _showFilterSheet(context, ref, filter),
              ),
              Expanded(
                child: visible.isEmpty
                    ? MoniqEmptyState.peaceful(
                        title: '고정된 공지가 없어요',
                        message: '공지 카드의 핀 아이콘을 눌러 상단에 고정하세요',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(
                            teamAnnouncementsProvider(teamId)),
                        child: SlidableAutoCloseBehavior(
                          child: ListView.builder(
                            padding: AppSpacing.screenAll,
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final a = visible[index];
                              final isPinnedLocally =
                                  pinnedIds.contains(a.id);
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: Slidable(
                                  key: ValueKey(a.id),
                                  startActionPane: ActionPane(
                                    motion: const BehindMotion(),
                                    extentRatio: 0.28,
                                    children: [
                                      SlidableAction(
                                        onPressed: (_) => ref
                                            .read(
                                                pinnedAnnouncementIdsProvider
                                                    .notifier)
                                            .toggle(a.id),
                                        backgroundColor: isPinnedLocally
                                            ? AppColors.brandOrange
                                            : AppColors.primary,
                                        foregroundColor: Colors.white,
                                        icon: isPinnedLocally
                                            ? Icons.push_pin
                                            : Icons.push_pin_outlined,
                                        label:
                                            isPinnedLocally ? '해제' : '고정',
                                        borderRadius:
                                            AppRadius.borderRadiusLg,
                                      ),
                                    ],
                                  ),
                                  child: AnnouncementListTile(
                                    key: ValueKey('tile_${a.id}'),
                                    announcement: a,
                                    isPinnedLocally: isPinnedLocally,
                                    onTap: () =>
                                        _showDetail(context, ref, a),
                                    onTogglePin: () => ref
                                        .read(pinnedAnnouncementIdsProvider
                                            .notifier)
                                        .toggle(a.id),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context,
    WidgetRef ref,
    _AnnouncementFilter current,
  ) async {
    final picked = await showAnnouncementFilterSheet<_AnnouncementFilter>(
      context: context,
      title: '공지 필터',
      selectedValue: current,
      options: const [
        AnnouncementFilterOption(
          value: _AnnouncementFilter.all,
          label: '전체 공지',
          icon: Icons.campaign_outlined,
        ),
        AnnouncementFilterOption(
          value: _AnnouncementFilter.pinned,
          label: '고정된 공지만',
          icon: Icons.push_pin_outlined,
        ),
      ],
    );
    if (picked != null) {
      ref.read(_teamAnnouncementFilterProvider.notifier).state =
          picked.value;
    }
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _AnnouncementCreateSheet(teamId: teamId),
    );
  }

  void _showDetail(
      BuildContext context, WidgetRef ref, AnnouncementModel a) {
    final myUserId = ref.read(currentUserProvider)?.id;
    final isMine = myUserId != null && a.createdBy == myUserId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (detailContext) => AnnouncementDetailPage(
          announcement: a,
          onEdit: isMine
              ? () async {
                  final updated = await showAnnouncementEditSheet(
                      detailContext, a);
                  if (updated == true) {
                    ref.invalidate(teamAnnouncementsProvider(teamId));
                    ref.invalidate(myAnnouncementsProvider);
                    if (detailContext.mounted) {
                      Navigator.pop(detailContext);
                    }
                  }
                }
              : null,
          onDelete: () async {
            final repo = ref.read(announcementRepositoryProvider);
            await repo.delete(a.id);
            ref.invalidate(teamAnnouncementsProvider(teamId));
            ref.invalidate(myAnnouncementsProvider);
          },
        ),
      ),
    );
  }
}

class _AnnouncementCreateSheet extends ConsumerStatefulWidget {
  const _AnnouncementCreateSheet({required this.teamId});
  final String teamId;

  @override
  ConsumerState<_AnnouncementCreateSheet> createState() =>
      _AnnouncementCreateSheetState();
}

class _AnnouncementCreateSheetState
    extends ConsumerState<_AnnouncementCreateSheet> {
  final _titleC = TextEditingController();
  final _contentC = TextEditingController();
  final List<_PendingAttachment> _pending = [];
  bool _saving = false;

  @override
  void dispose() {
    _titleC.dispose();
    _contentC.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('사진 라이브러리에서 선택'),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('파일 선택'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    if (choice == 'photo') {
      final picker = ImagePicker();
      // 업로드 시간 단축: 리사이즈 + 품질 85
      final picked = await picker.pickMultiImage(
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked.isEmpty) return;
      setState(() {
        for (final x in picked) {
          _pending.add(_PendingAttachment(name: x.name, path: x.path));
        }
      });
    } else if (choice == 'camera') {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (x == null) return;
      setState(() {
        _pending.add(_PendingAttachment(name: x.name, path: x.path));
      });
    } else if (choice == 'file') {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null) return;
      setState(() {
        for (final f in result.files) {
          if (f.path != null) {
            _pending.add(_PendingAttachment(name: f.name, path: f.path!));
          }
        }
      });
    }
  }

  Future<void> _submit() async {
    final title = _titleC.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(announcementRepositoryProvider);
      // 첨부 업로드 — 병렬
      final urls = await Future.wait(_pending.map((p) => repo.uploadAttachment(
            teamId: widget.teamId,
            file: File(p.path),
            filename: p.name,
          )));
      await repo.create(
        teamId: widget.teamId,
        title: title,
        content: _contentC.text.trim().isNotEmpty ? _contentC.text.trim() : null,
        attachmentUrls: urls,
      );
      ref.invalidate(teamAnnouncementsProvider(widget.teamId));
      ref.invalidate(myAnnouncementsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공지사항이 등록되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        top: AppSpacing.xxl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('공지사항 작성',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xxl),
          TextField(
            controller: _titleC,
            decoration: const InputDecoration(
              hintText: '제목',
              prefixIcon: Icon(Icons.title),
            ),
            maxLength: 50,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _contentC,
            decoration: const InputDecoration(
              hintText: '내용 (선택)',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 6,
            maxLength: 2000,
          ),
          const SizedBox(height: AppSpacing.md),
          // 첨부파일 영역
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving ? null : _pickAttachment,
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('첨부파일 추가'),
            ),
          ),
          if (_pending.isNotEmpty)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: _pending
                  .asMap()
                  .entries
                  .map((e) => Chip(
                        label: Text(e.value.name,
                            style: const TextStyle(fontSize: 11)),
                        onDeleted: _saving
                            ? null
                            : () => setState(() => _pending.removeAt(e.key)),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          const SizedBox(height: AppSpacing.xxl),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('등록'),
          ),
        ],
      ),
    );
  }
}

class _PendingAttachment {
  _PendingAttachment({required this.name, required this.path});
  final String name;
  final String path;
}

/// 공지 수정 바텀시트를 띄운다. 저장 성공 시 true, 취소/변경 없음은 null/false.
Future<bool?> showAnnouncementEditSheet(
  BuildContext context,
  AnnouncementModel announcement,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => _AnnouncementEditSheet(announcement: announcement),
  );
}

class _AnnouncementEditSheet extends ConsumerStatefulWidget {
  const _AnnouncementEditSheet({required this.announcement});
  final AnnouncementModel announcement;

  @override
  ConsumerState<_AnnouncementEditSheet> createState() =>
      _AnnouncementEditSheetState();
}

class _AnnouncementEditSheetState
    extends ConsumerState<_AnnouncementEditSheet> {
  late final TextEditingController _titleC;
  late final TextEditingController _contentC;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleC = TextEditingController(text: widget.announcement.title);
    _contentC = TextEditingController(text: widget.announcement.content ?? '');
  }

  @override
  void dispose() {
    _titleC.dispose();
    _contentC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleC.text.trim();
    if (title.isEmpty) return;

    final content = _contentC.text.trim();
    final originalContent = widget.announcement.content ?? '';

    final titleChanged = title != widget.announcement.title;
    final contentChanged = content != originalContent;
    if (!titleChanged && !contentChanged) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(announcementRepositoryProvider).update(
            widget.announcement.id,
            title: titleChanged ? title : null,
            content: contentChanged ? content : null,
          );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공지사항이 수정되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        top: AppSpacing.xxl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('공지사항 수정',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xxl),
          TextField(
            controller: _titleC,
            decoration: const InputDecoration(
              hintText: '제목',
              prefixIcon: Icon(Icons.title),
            ),
            maxLength: 50,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _contentC,
            decoration: const InputDecoration(
              hintText: '내용 (선택)',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 6,
            maxLength: 2000,
          ),
          const SizedBox(height: AppSpacing.md),
          const SizedBox(height: AppSpacing.xxl),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 공용 위젯들 (팀 관리 + 홈탭 공유)
// ══════════════════════════════════════════════

/// 팀 공지사항 화면 상단의 바텀시트 필터 셀렉터 바.
class _AnnouncementFilterBar extends StatelessWidget {
  const _AnnouncementFilterBar({
    required this.filter,
    required this.onTap,
  });

  final _AnnouncementFilter filter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        filter == _AnnouncementFilter.pinned ? '고정된 공지만' : '전체 공지';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.xs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnnouncementFilterChip(
          label: label,
          onTap: onTap,
        ),
      ),
    );
  }
}

/// 공지사항 리스트 타일 (공용)
///
/// 본문 미리보기 대신 작성자(아바타+이름)와 댓글 수를 노출한다.
/// 작성자/댓글 수는 [AnnouncementModel]에 조인·집계로 함께 담겨 오므로
/// 추가 조회 없이 모델에서 바로 읽는다.
class AnnouncementListTile extends StatelessWidget {
  const AnnouncementListTile({
    super.key,
    required this.announcement,
    this.teamName,
    required this.onTap,
    this.isPinnedLocally = false,
    this.onTogglePin,
  });

  final AnnouncementModel announcement;
  final String? teamName;
  final VoidCallback onTap;
  final bool isPinnedLocally;
  final VoidCallback? onTogglePin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MM.dd');
    final isDark = theme.brightness == Brightness.dark;

    final title = announcement.title;
    final createdAt = announcement.createdAt;
    final author = AnnouncementAuthorInfo.fromAnnouncement(announcement);
    final commentCount = announcement.commentCount;

    return Material(
      color: isDark
          ? colorScheme.surfaceContainer
          : colorScheme.surfaceContainerLowest,
      borderRadius: AppRadius.borderRadiusLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusLg,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AuthorAvatar(
                avatarUrl: author.avatarUrl,
                displayName: author.displayName,
                radius: 20,
                primary: colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          author.displayName,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (teamName != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: AppRadius.borderRadiusSm,
                            ),
                            child: Text(
                              teamName!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (createdAt != null)
                          Text(
                            dateFormat.format(createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(width: AppSpacing.xxs),
                        Icon(Icons.chevron_right,
                            size: 16, color: colorScheme.outline),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        if (isPinnedLocally) ...[
                          Icon(Icons.push_pin,
                              size: 13, color: AppColors.brandOrange),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _CommentCountBadge(count: commentCount),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 공지 카드용 작성자 아바타 (이니셜 폴백 포함).
class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({
    required this.avatarUrl,
    required this.displayName,
    required this.radius,
    required this.primary,
  });

  final String? avatarUrl;
  final String displayName;
  final double radius;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: primary.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      ),
    );
  }
}

/// 카드에 표시하는 댓글 수 뱃지.
class _CommentCountBadge extends StatelessWidget {
  const _CommentCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = '$count';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.mode_comment_outlined,
          size: 12,
          color: cs.onSurfaceVariant,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTypography.captionSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 공지사항 상세 페이지 (공용) — 첨부파일 + 댓글 지원
class AnnouncementDetailPage extends ConsumerStatefulWidget {
  const AnnouncementDetailPage({
    super.key,
    required this.announcement,
    this.teamName,
    this.onDelete,
    this.onEdit,
  });

  final AnnouncementModel announcement;
  final String? teamName;
  final Future<void> Function()? onDelete;
  final Future<void> Function()? onEdit;

  @override
  ConsumerState<AnnouncementDetailPage> createState() =>
      _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState
    extends ConsumerState<AnnouncementDetailPage> {
  final _commentC = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _commentC.dispose();
    super.dispose();
  }

  void _openImageViewer(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addComment() async {
    final text = _commentC.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      final repo = ref.read(announcementRepositoryProvider);
      await repo.addComment(
        announcementId: widget.announcement.id,
        teamId: widget.announcement.teamId,
        content: text,
      );
      _commentC.clear();
      ref.invalidate(announcementCommentsProvider(widget.announcement.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 등록 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await ref
          .read(announcementRepositoryProvider)
          .deleteComment(commentId);
      ref.invalidate(announcementCommentsProvider(widget.announcement.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final commentsAsync =
        ref.watch(announcementCommentsProvider(a.id));
    final myUserId = ref.watch(currentUserProvider)?.id;

    final trailingActions = <Widget>[
      if (widget.onEdit != null)
        MoniqAppBarAction(
          icon: Icons.edit_outlined,
          onTap: () => widget.onEdit!(),
        ),
      if (widget.onDelete != null)
        MoniqAppBarAction(
          icon: Icons.delete_outline_rounded,
          tint: AppColors.error,
          onTap: () async {
            final ok = await showMoniqConfirmSheet(
              context: context,
              title: '공지를 삭제할까요?',
              message: '이 공지사항이 영구적으로 삭제돼요.',
              confirmLabel: '삭제',
              destructive: true,
            );
            if (ok) {
              await widget.onDelete!();
              if (context.mounted) Navigator.pop(context);
            }
          },
        ),
    ];

    return Scaffold(
      appBar: MoniqAppBar(
        title: widget.teamName ?? '공지사항',
        trailing: trailingActions.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: trailingActions),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.screenAll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.teamName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.borderRadiusSm,
                      ),
                      child: Text(
                        widget.teamName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Text(
                    a.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // 작성자 + 작성 일시
                  _DetailAuthorLine(
                    announcement: a,
                    dateFormat: dateFormat,
                  ),
                  const Divider(height: AppSpacing.xxxl),
                  if (a.content != null && a.content!.isNotEmpty)
                    Text(
                      a.content!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.6),
                    ),

                  // 첨부파일
                  if (a.attachmentUrls.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text('첨부파일',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.sm),
                    // 이미지는 미리보기, 비이미지는 chip
                    Builder(
                      builder: (context) {
                        const imgExts = [
                          '.png',
                          '.jpg',
                          '.jpeg',
                          '.gif',
                          '.webp',
                          '.heic',
                          '.heif',
                          '.bmp',
                        ];
                        bool isImage(String url) {
                          final lower =
                              url.split('?').first.toLowerCase();
                          return imgExts.any((e) => lower.endsWith(e));
                        }

                        final images = a.attachmentUrls
                            .where(isImage)
                            .toList();
                        final files = a.attachmentUrls
                            .where((u) => !isImage(u))
                            .toList();

                        return Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            if (images.isNotEmpty)
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: images.map((url) {
                                  return GestureDetector(
                                    onTap: () => _openImageViewer(
                                        context, url),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(
                                              AppRadius.md),
                                      child: Image.network(
                                        url,
                                        width: 140,
                                        height: 140,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          width: 140,
                                          height: 140,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: const Icon(
                                              Icons.broken_image_outlined),
                                        ),
                                        loadingBuilder:
                                            (ctx, child, progress) {
                                          if (progress == null) {
                                            return child;
                                          }
                                          return Container(
                                            width: 140,
                                            height: 140,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHigh,
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            if (images.isNotEmpty && files.isNotEmpty)
                              const SizedBox(height: AppSpacing.sm),
                            if (files.isNotEmpty)
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: files.map((url) {
                                  final filename = url.split('/').last;
                                  return ActionChip(
                                    avatar: const Icon(Icons.attach_file,
                                        size: 16),
                                    label: Text(filename,
                                        style: const TextStyle(
                                            fontSize: 12)),
                                    onPressed: () async {
                                      final uri = Uri.tryParse(url);
                                      if (uri != null &&
                                          await canLaunchUrl(uri)) {
                                        await launchUrl(uri,
                                            mode: LaunchMode
                                                .externalApplication);
                                      } else {
                                        await Clipboard.setData(
                                            ClipboardData(text: url));
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  '파일 링크가 클립보드에 복사되었습니다'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                          ],
                        );
                      },
                    ),
                  ],

                  // 댓글 섹션
                  const SizedBox(height: AppSpacing.xxl),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  Text('댓글',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  commentsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text('댓글을 불러올 수 없습니다',
                        style: TextStyle(color: AppColors.error)),
                    data: (comments) {
                      if (comments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          child: Text('아직 댓글이 없습니다',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                              )),
                        );
                      }
                      return Column(
                        children: comments.map((cw) {
                          final isMine = cw.comment.userId == myUserId;
                          return Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  child: Text(
                                    cw.displayName.isNotEmpty
                                        ? cw.displayName[0]
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(cw.displayName,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              )),
                                          const SizedBox(
                                              width: AppSpacing.xs),
                                          if (cw.comment.createdAt != null)
                                            Text(
                                              dateFormat.format(
                                                  cw.comment.createdAt!),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                        ],
                                      ),
                                      Text(cw.comment.content,
                                          style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                if (isMine)
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        _deleteComment(cw.comment.id),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // 댓글 입력
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.sm,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentC,
                      decoration: const InputDecoration(
                        hintText: '댓글 입력',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: _posting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _posting ? null : _addComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 공지 상세 헤더의 작성자 + 작성 일시 한 줄.
class _DetailAuthorLine extends StatelessWidget {
  const _DetailAuthorLine({
    required this.announcement,
    required this.dateFormat,
  });

  final AnnouncementModel announcement;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final author =
        AnnouncementAuthorInfo.fromAnnouncement(announcement);
    final createdAt = announcement.createdAt;

    return AnnouncementAuthor(
      name: author.displayName,
      avatarUrl: author.avatarUrl,
      avatarRadius: 10,
      trailing: createdAt == null
          ? null
          : Text(
              dateFormat.format(createdAt),
              style: AppTypography.caption.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
    );
  }
}
