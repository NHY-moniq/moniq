import 'package:flutter/material.dart';

import 'package:moniq/presentation/theme/app_spacing.dart';

/// 로딩 자리표시용 블록. 화면 뼈대를 미리 그려 "빈 화면 → 콘텐츠"의 급격한
/// 전환과 레이아웃 점프를 없앤다.
///
/// 전체 화면 스피너(MoniqLoadingView)와 달리 최종 레이아웃과 같은 자리를
/// 차지하므로, 데이터가 도착했을 때 요소가 크게 움직이지 않는다.
class MoniqSkeletonBox extends StatelessWidget {
  const MoniqSkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
    this.shape = BoxShape.rectangle,
  });

  /// 원형 아바타 자리표시.
  const MoniqSkeletonBox.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = 0,
        shape = BoxShape.circle;

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// 스켈레톤 묶음에 은은한 펄스를 입힌다.
///
/// 블록마다 컨트롤러를 두면 한 화면에 수십 개의 티커가 돌기 때문에,
/// 화면 단위로 하나의 애니메이션만 사용한다.
class MoniqSkeletonGroup extends StatefulWidget {
  const MoniqSkeletonGroup({super.key, required this.child});

  final Widget child;

  @override
  State<MoniqSkeletonGroup> createState() => _MoniqSkeletonGroupState();
}

class _MoniqSkeletonGroupState extends State<MoniqSkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

/// 캘린더 격자 뼈대 — 월 타이틀 + 요일 헤더 + 주 행.
class MoniqCalendarSkeleton extends StatelessWidget {
  const MoniqCalendarSkeleton({
    super.key,
    this.rowCount = 5,
    this.rowHeight = 80,
  });

  final int rowCount;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenHorizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              MoniqSkeletonBox(width: 120, height: 24),
              Spacer(),
              MoniqSkeletonBox(width: 72, height: 28, radius: AppRadius.full),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: List.generate(
              7,
              (_) => const Expanded(
                child: Center(child: MoniqSkeletonBox(width: 18, height: 12)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...List.generate(
            rowCount,
            (_) => SizedBox(
              height: rowHeight,
              child: Row(
                children: List.generate(
                  7,
                  (__) => const Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: MoniqSkeletonBox(height: 44),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 홈 탭 뼈대 — 인사말 + 히어로 카드 + 2단 카드 + 팀 소식.
class MoniqHomeSkeleton extends StatelessWidget {
  const MoniqHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return MoniqSkeletonGroup(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: AppSpacing.screenHorizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SizedBox(height: AppSpacing.sm),
              MoniqSkeletonBox(width: 180, height: 26),
              SizedBox(height: AppSpacing.sm),
              MoniqSkeletonBox(width: 220, height: 16),
              SizedBox(height: AppSpacing.xxl),
              MoniqSkeletonBox(height: 168, radius: AppRadius.lg),
              SizedBox(height: AppSpacing.lg),
              SizedBox(height: 180, child: _HomeCardRowSkeleton()),
              SizedBox(height: AppSpacing.xxl),
              MoniqSkeletonBox(width: 90, height: 22),
              SizedBox(height: AppSpacing.md),
              MoniqSkeletonBox(height: 96, radius: AppRadius.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCardRowSkeleton extends StatelessWidget {
  const _HomeCardRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: MoniqSkeletonBox(
                  height: double.infinity,
                  radius: AppRadius.md,
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Expanded(
                child: MoniqSkeletonBox(
                  height: double.infinity,
                  radius: AppRadius.md,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: MoniqSkeletonBox(
            height: double.infinity,
            radius: AppRadius.md,
          ),
        ),
      ],
    );
  }
}

/// 캘린더 탭 뼈대 — 격자 + 선택일 패널.
class MoniqCalendarScreenSkeleton extends StatelessWidget {
  const MoniqCalendarScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return MoniqSkeletonGroup(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm),
            const MoniqCalendarSkeleton(),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: AppSpacing.screenHorizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  MoniqSkeletonBox(width: 140, height: 20),
                  SizedBox(height: AppSpacing.md),
                  MoniqSkeletonBox(height: 72, radius: AppRadius.md),
                  SizedBox(height: AppSpacing.sm),
                  MoniqSkeletonBox(height: 72, radius: AppRadius.md),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 팀 탭 뼈대 — 주간 격자 + 로스터 목록.
class MoniqTeamCalendarSkeleton extends StatelessWidget {
  const MoniqTeamCalendarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return MoniqSkeletonGroup(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm),
            const MoniqCalendarSkeleton(rowCount: 2),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: AppSpacing.screenHorizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MoniqSkeletonBox(width: 120, height: 20),
                  const SizedBox(height: AppSpacing.md),
                  ...List.generate(
                    3,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        children: [
                          MoniqSkeletonBox.circle(size: 40),
                          SizedBox(width: AppSpacing.md),
                          Expanded(child: MoniqSkeletonBox(height: 18)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
