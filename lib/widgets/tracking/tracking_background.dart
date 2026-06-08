import 'package:flutter/material.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';

/// Background for the tracking screen.
///
/// Renders, over a themed cream fill:
///   1. The remote background image from the theme endpoint
///      ([AppRemoteAssets.backgroundUrl]), if provided.
///   2. Otherwise the bundled `assets/images/background.png` watermark.
///   3. Nothing (flat cream) if neither resolves.
///
/// The image is washed with the themed cream so it reads as a subtle
/// backdrop rather than competing with the foreground content.
class TrackingBackground extends StatelessWidget {
  final Widget child;
  const TrackingBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final remote = AppRemoteAssets.backgroundUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.backgroundCream),
        if (remote != null)
          Image.network(
            remote,
            fit: BoxFit.cover,
            color: AppColors.backgroundCream.withValues(alpha: 0.2),
            colorBlendMode: BlendMode.lighten,
            errorBuilder: (_, __, ___) => _bundled(),
          )
        else
          _bundled(),
        child,
      ],
    );
  }

  Widget _bundled() {
    return Image.asset(
      'assets/images/background.png',
      fit: BoxFit.cover,
      color: AppColors.backgroundCream.withValues(alpha: 0.2),
      colorBlendMode: BlendMode.lighten,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
