import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/tutorial_providers.dart';
import 'package:moniq/presentation/theme/app_colors.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/viewmodels/team_detail_viewmodel.dart';
import 'package:moniq/presentation/widgets/common/moniq_app_bar.dart';
import 'package:moniq/presentation/widgets/common/moniq_error_view.dart';
import 'package:moniq/presentation/widgets/common/moniq_loading_view.dart';
import 'package:moniq/presentation/widgets/tutorial/tutorial_controller.dart';
import 'package:moniq/presentation/widgets/tutorial/tutorial_step.dart';

import 'appointment_management_screen.dart';
import 'team_detail_dialogs.dart';
import 'team_detail_widgets.dart';

class TeamDetailScreen extends ConsumerStatefulWidget {
  const TeamDetailScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends ConsumerState<TeamDetailScreen> {
  // GlobalKeys — 조직 팀용
  final _memberKey = GlobalKey();
  final _settingsKey = GlobalKey();
  final _wantedSectionKey = GlobalKey(); // 원티드 수집 + 원티드 입력 묶음
  final _scheduleKey = GlobalKey();
  final _exchangeKey = GlobalKey();

  // GlobalKeys — 개인 팀용
  final _memberCalendarKey = GlobalKey();

  TutorialController? _tutorial;
  bool _tutorialLaunched = false;
  bool _tutorialScheduled = false; // 중복 스케줄 방지

  @override
  void initState() {
    super.initState();
    // 화면 재진입 시 멤버 역할(권한) 변경을 반영하기 위해 1회 새로고침.
    // 이미 캐시된 경우에만 invalidate → 최초 진입 시 이중 조회를 막아 성능 영향 최소화.
    // (재조회 중에도 skipLoadingOnReload로 기존 화면을 유지해 깜빡임 없음)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cached = ref.read(teamDetailViewModelProvider(widget.teamId));
      if (cached.hasValue) {
        ref.invalidate(teamDetailViewModelProvider(widget.teamId));
      }
    });
  }

  @override
  void dispose() {
    _tutorial?.dispose();
    super.dispose();
  }

  void _startTutorial(String teamType) {
    final isPersonal = teamType == 'personal';

    final steps = isPersonal
        ? [
            TutorialStep(
              key: _memberKey,
              title: '멤버 초대',
              message: '초대 코드를 공유해서 친구들을 팀에 초대하세요.',
            ),
            TutorialStep(
              key: _memberCalendarKey,
              title: '멤버 근무 현황',
              message:
                  '각 멤버의 즐겨찾기 팀 근무가 여기서 보여요. '
                  '언제 다 같이 쉬는지 한눈에 확인하세요.',
            ),
          ]
        : [
            TutorialStep(
              key: _memberKey,
              title: '멤버 관리',
              message:
                  '초대 코드를 공유해서 팀원을 초대하고, '
                  '역할과 숙련도를 설정하세요.',
            ),
            TutorialStep(
              key: _settingsKey,
              title: '팀 상세 설정',
              message:
                  '근무 유형(데이·이브닝·나이트 등)을 포함한 고정 규칙을 '
                  '설정하여 근무표 자동 생성에 반영할 수 있어요.',
            ),
            TutorialStep(
              key: _wantedSectionKey,
              title: '원티드',
              message:
                  '원티드 수집으로 원하는 날짜를 팀원들에게 받고(관리자 기능), '
                  '원티드 입력으로 내 희망 날짜를 직접 등록할 수 있어요.',
            ),
            TutorialStep(
              key: _scheduleKey,
              title: '근무표 자동 생성',
              message: '설정한 규칙과 원티드를 반영해 근무표를 자동으로 만들어요.',
            ),
            TutorialStep(
              key: _exchangeKey,
              title: '교환/변경 요청',
              message: '근무표 확정 후 팀원 간 근무 교환·변경 요청을 여기서 관리해요.',
            ),
          ];

    _tutorial = TutorialController(steps: steps);
    _tutorial!.start(context);
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(teamDetailViewModelProvider(widget.teamId));

    // 튜토리얼 펜딩 감지
    final pending = ref.watch(tutorialPendingProvider);
    if (pending?.teamId == widget.teamId && !_tutorialLaunched) {
      // 펜딩 클리어 + 실행 예약
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(tutorialPendingProvider.notifier).state = null;
      });
      _tutorialLaunched = true;
    }

    return Scaffold(
      appBar: MoniqAppBar(
        title: '팀 관리',
        onLeadingTap: () {
          if (Navigator.of(context).canPop()) {
            context.pop();
          } else {
            context.go('/teams');
          }
        },
      ),
      body: detailAsync.when(
        // 재진입 새로고침 중에는 기존 데이터를 유지(스피너 깜빡임 방지).
        skipLoadingOnReload: true,
        loading: () => const MoniqLoadingView(),
        error: (e, _) => MoniqErrorView(
          message: '팀 정보를 불러올 수 없습니다',
          onRetry: () =>
              ref.invalidate(teamDetailViewModelProvider(widget.teamId)),
        ),
        data: (state) {
          // 데이터 로드 완료 후 튜토리얼 시작 — 라우트 전환 애니메이션 끝난 뒤 실행
          if (_tutorialLaunched && _tutorial == null && !_tutorialScheduled) {
            _tutorialScheduled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final animation = ModalRoute.of(context)?.animation;
              void doStart() {
                if (mounted) _startTutorial(state.team.teamType);
              }

              if (animation == null ||
                  animation.status == AnimationStatus.completed) {
                doStart();
              } else {
                void onStatus(AnimationStatus s) {
                  if (s == AnimationStatus.completed) {
                    animation.removeStatusListener(onStatus);
                    doStart();
                  }
                }

                animation.addStatusListener(onStatus);
              }
            });
          }

          final isPersonal = state.team.teamType == 'personal';
          return SingleChildScrollView(
            padding: AppSpacing.screenAll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero profile section
                TeamDetailHeroSection(
                  name: state.team.name,
                  description: state.team.description,
                  icon: state.team.icon,
                  inviteCode: state.team.inviteCode,
                  isAdmin: state.isAdmin,
                  onEdit: () => showEditTeamSheet(
                    context: context,
                    ref: ref,
                    teamId: widget.teamId,
                    state: state,
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),

                // Section header — 팀 설정
                _SectionHeader(label: '팀 설정'),
                const SizedBox(height: AppSpacing.lg),

                TeamDetailBubbleMenuCard(
                  key: _memberKey,
                  icon: Icons.people_outline,
                  iconColor: Theme.of(context).colorScheme.tertiary,
                  title: '멤버 관리',
                  subtitle: '${state.members.length}명',
                  onTap: () => context.push('/teams/${widget.teamId}/members'),
                ),

                // 개인 팀: 팀 상세 설정 숨김
                if (!isPersonal) ...[
                  const SizedBox(height: AppSpacing.md),
                  TeamDetailBubbleMenuCard(
                    key: _settingsKey,
                    icon: Icons.settings_outlined,
                    iconColor: Theme.of(context).colorScheme.secondary,
                    title: '팀 상세 설정',
                    subtitle: '근무 유형 · 고정 규칙',
                    onTap: () =>
                        context.push('/teams/${widget.teamId}/settings'),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxxl),

                // 개인 팀: 멤버 근무 섹션 / 조직 팀: 스케줄 운영 섹션
                if (isPersonal) ...[
                  _SectionHeader(label: '멤버 근무'),
                  const SizedBox(height: AppSpacing.lg),
                  TeamDetailBubbleMenuCard(
                    key: _memberCalendarKey,
                    icon: Icons.calendar_month_outlined,
                    iconColor: Theme.of(context).colorScheme.primary,
                    title: '멤버 근무 현황',
                    subtitle: '즐겨찾기 팀 근무 · 오프 겹침 보기',
                    onTap: () => context.push(
                      '/teams/${widget.teamId}/personal-calendar',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TeamDetailBubbleMenuCard(
                    icon: Icons.event_note_rounded,
                    iconColor: Theme.of(context).colorScheme.primary,
                    title: '약속 관리',
                    subtitle: '약속 보기 · 내 캘린더에 추가',
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AppointmentManagementScreen(
                          teamId: widget.teamId,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  _SectionHeader(label: '스케줄 운영'),
                  const SizedBox(height: AppSpacing.lg),

                  Opacity(
                    opacity: state.isAdmin ? 1.0 : 0.5,
                    child: TeamDetailBubbleMenuCard(
                      key: _scheduleKey,
                      icon: Icons.auto_awesome_outlined,
                      iconColor: Theme.of(context).colorScheme.primary,
                      title: '근무표 자동 생성',
                      subtitle: state.isAdmin
                          ? '규칙 설정 · 근무표 생성'
                          : '팀 관리자만 사용 가능',
                      onTap: () {
                        if (state.isAdmin) {
                          context.push(
                            '/teams/${widget.teamId}/schedule-rules',
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('팀 관리자만 사용 가능한 기능입니다.'),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // 원티드 수집 + 원티드 입력을 하나의 키로 묶어 튜토리얼 스포트라이트 적용
                  Column(
                    key: _wantedSectionKey,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Opacity(
                        opacity: state.isAdmin ? 1.0 : 0.5,
                        child: TeamDetailBubbleMenuCard(
                          icon: Icons.event_note_outlined,
                          iconColor: AppColors.brandOrange,
                          title: '원티드 수집',
                          subtitle: state.isAdmin
                              ? '근무표 생성 전 팀원 원티드 수집'
                              : '팀 관리자만 사용 가능',
                          onTap: () {
                            if (state.isAdmin) {
                              context.push(
                                '/teams/${widget.teamId}/wanted'
                                '?teamName=${Uri.encodeComponent(state.team.name)}',
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('팀 관리자만 사용 가능한 기능입니다.'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TeamDetailBubbleMenuCard(
                        icon: Icons.edit_calendar_outlined,
                        iconColor: Theme.of(context).colorScheme.secondary,
                        title: '원티드 입력',
                        subtitle: '내 원티드 날짜 입력하기',
                        onTap: () => context.push(
                          '/teams/${widget.teamId}/wanted/entry',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TeamDetailBubbleMenuCard(
                    key: _exchangeKey,
                    icon: Icons.swap_horiz_outlined,
                    iconColor: Theme.of(context).colorScheme.tertiary,
                    title: '교환/변경 요청',
                    subtitle: '근무 교환 및 변경 요청 관리',
                    onTap: () =>
                        context.push('/teams/${widget.teamId}/requests'),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxxl),
                const Divider(),
                const SizedBox(height: AppSpacing.lg),

                // Leave / Delete
                TeamDetailBubbleMenuCard(
                  icon: Icons.exit_to_app,
                  iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  title: '팀 나가기',
                  onTap: () => showConfirmLeaveDialog(
                    context: context,
                    ref: ref,
                    teamId: widget.teamId,
                    state: state,
                  ),
                ),
                if (state.isAdmin) ...[
                  const SizedBox(height: AppSpacing.md),
                  TeamDetailBubbleMenuCard(
                    icon: Icons.delete_outline,
                    iconColor: Theme.of(context).colorScheme.error,
                    title: '팀 삭제',
                    titleColor: Theme.of(context).colorScheme.error,
                    onTap: () => showConfirmDeleteDialog(
                      context: context,
                      ref: ref,
                      teamId: widget.teamId,
                      state: state,
                    ),
                  ),
                ],

                // Bottom padding for floating nav
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
