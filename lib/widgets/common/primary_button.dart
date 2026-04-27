import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

enum PrimaryButtonVariant { solid, teal }

/// Full-width rounded pill button used on every CTA in the app.
///
/// Variants match the Figma:
///   - [PrimaryButtonVariant.solid] -> red (Start / Stop / Retry / Login Again)
///   - [PrimaryButtonVariant.teal]  -> teal (reserved for secondary actions)
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PrimaryButtonVariant variant;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PrimaryButtonVariant.solid,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = variant == PrimaryButtonVariant.teal
        ? AppColors.secondaryTeal
        : AppColors.primaryRed;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppColors.surfaceWhite),
                ),
              )
            : Text(label, style: AppTextStyles.button, ),
      ),
    );
  }
}
