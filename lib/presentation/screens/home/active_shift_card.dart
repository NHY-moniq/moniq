import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:moniq/presentation/theme/app_spacing.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';
import 'package:moniq/presentation/widgets/common/character_blob.dart';

// ════════════════════════════════════════════════
// Active Shift Card (full-width with character)
// ════════════════════════════════════════════════

class ActiveShiftCard extends StatelessWidget {
  const ActiveShiftCard({
    super.key,
    required this.shiftTheme,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.teamName,
    required this.hasShift,
  });

  final ShiftThemeData shiftTheme;
  final String shiftName;
  final String? startTime;
  final String? endTime;
  final String? teamName;
  final bool hasShift;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            shiftTheme.cardColor,
            shiftTheme.cardColor.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Stack(
        children: [
          // Decorative blur circle (top-right)
          Positioned(
            top: -48,
            right: -48,
            child: Container(
              width: 192,
              height: 192,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: shiftTheme.primary.withValues(alpha: 0.15),
              ),
            ),
          ),

          // Character PNG or CharacterBlob fallback
          Positioned(
            right: -16,
            bottom: -16,
            child: Transform.rotate(
              angle: 0.21,
              child: Opacity(
                opacity: 0.25,
                child: shiftTheme.characterAsset.isNotEmpty
                    ? Image.asset(
                        shiftTheme.characterAsset,
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                      )
                    : CharacterBlob(
                        type: CharacterType.grey,
                        size: 160,
                        showEyes: true,
                        sleeping: true,
                      ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glass badge
                GlassBadge(
                  label: hasShift ? 'Active Shift' : 'No Shift',
                  showPulse: hasShift,
                  textColor: shiftTheme.onPrimary,
                ),
                const SizedBox(height: 20),

                // Shift name
                Text(
                  shiftTheme.displayName,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: shiftTheme.onPrimary,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Time
                if (hasShift && startTime != null && endTime != null)
                  Text(
                    '$startTime — $endTime',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: shiftTheme.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                const SizedBox(height: 16),

                // Location / Team chips
                if (hasShift)
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      GlassChip(
                        icon: Icons.group,
                        label: teamName ?? '개인 일정',
                        textColor: shiftTheme.onPrimary,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Glass Badge
// ════════════════════════════════════════════════

class GlassBadge extends StatelessWidget {
  const GlassBadge({
    super.key,
    required this.label,
    required this.showPulse,
    required this.textColor,
  });

  final String label;
  final bool showPulse;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.borderRadiusFull,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: AppRadius.borderRadiusFull,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: textColor,
                  shape: BoxShape.circle,
                  boxShadow: showPulse
                      ? [
                          BoxShadow(
                            color: textColor.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// Glass Chip
// ════════════════════════════════════════════════

class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.icon,
    required this.label,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.borderRadiusFull,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: AppRadius.borderRadiusFull,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
