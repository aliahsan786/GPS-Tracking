import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Background for the tracking screen. Attempts to render
/// `assets/images/tracking_bg.png` (the faded "BREAKING NEWS" watermark
/// from the Figma); falls back to flat cream when missing.
class TrackingBackground extends StatelessWidget {
  final Widget child;
  const TrackingBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.backgroundCream),
        Image.asset(
          'assets/images/background.png',
          fit: BoxFit.cover,
          color: AppColors.backgroundCream.withValues(alpha: 0.2),
          colorBlendMode: BlendMode.lighten,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        child,
      ],
    );
  }
}
