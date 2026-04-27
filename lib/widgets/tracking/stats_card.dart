import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// The orange activity card: "LAST ACTIVITY / DIST / TIME" with optional
/// values. When values are null, renders "--" placeholders (Idle state).
class StatsCard extends StatelessWidget {
  final String? activityName;
  final String? distance;
  final String? time;

  const StatsCard({
    super.key,
    this.activityName,
    this.distance,
    this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardOrange,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('LAST ACTIVITY', style: AppTextStyles.label),
              const Spacer(),
              Image.asset("assets/icons/last_activity_card_icon.png", height: 17, width: 17,color: AppColors.textOnOrangeSoft,)
              
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            activityName ?? '--',
            style: activityName == null
                ? AppTextStyles.h3.copyWith(color: AppColors.textOnOrangeStrong)
                : AppTextStyles.h2.copyWith(color: AppColors.textOnOrangeStrong),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Stat(label: 'DIST', value: distance ?? '--'),
              ),
              Expanded(
                child: _Stat(label: 'TIME', value: time ?? '--'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.h4.copyWith(
            color: AppColors.textOnOrangeStrong,
          ),
        ),
      ],
    );
  }
}
