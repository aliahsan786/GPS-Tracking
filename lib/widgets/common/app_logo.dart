import 'package:flutter/material.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Renders the brand logo.
///
/// Resolution order:
///   1. Remote logo from the theme endpoint ([AppRemoteAssets.logoUrl]).
///   2. Bundled `assets/images/logo.png`.
///   3. A red "FF" text badge (last-resort so the app never crashes).
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final remote = AppRemoteAssets.logoUrl;
    if (remote != null) {
      return Image.network(
        remote,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _bundled(),
      );
    }
    return _bundled();
  }

  Widget _bundled() {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _FallbackBadge(size: size),
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  final double size;
  const _FallbackBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryRed, width: 2),
      ),
      child: Text(
        'FF',
        style: AppTextStyles.h1.copyWith(fontSize: size * 0.38),
      ),
    );
  }
}
