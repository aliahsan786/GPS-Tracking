import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Inline banner with icon + title + subtitle. Used for:
///   - "Authentication failed" on Login (S3)
///   - "No internet connection" offline banner (S7)
class AlertBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? background;
  final Color? borderColor;

  const AlertBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.background,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: background ?? AppColors.alertTint,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: borderColor ?? AppColors.primaryRed.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryRed, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body1),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.body3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
