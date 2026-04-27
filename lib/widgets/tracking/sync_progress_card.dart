import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../utils/formatters.dart';

/// Orange card shown on the Syncing state (S5).
/// Replaces the stats card while queued points are being flushed.
class SyncProgressCard extends StatelessWidget {
  final int bytesSent;
  final int bytesTotal;

  const SyncProgressCard({
    super.key,
    required this.bytesSent,
    required this.bytesTotal,
  });

  double get _percent => bytesTotal == 0 ? 0 : bytesSent / bytesTotal;

  @override
  Widget build(BuildContext context) {
    final pct = (_percent * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.cardOrange,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  value: _percent,
                  color: AppColors.primaryRed,
                  backgroundColor:
                      AppColors.primaryRed.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Syncing data...',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.textOnOrangeStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _percent,
              minHeight: 6,
              color: AppColors.primaryRed,
              backgroundColor:
                  AppColors.primaryRed.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '${Formatters.bytes(bytesSent)} of ${Formatters.bytes(bytesTotal)}',
                style: AppTextStyles.body3.copyWith(
                  color: AppColors.textOnOrangeSoft,
                ),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: AppTextStyles.body1.copyWith(
                  color: AppColors.textOnOrangeStrong,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
