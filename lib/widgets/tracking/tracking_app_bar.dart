import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../common/app_logo.dart';

/// Top bar specific to the Tracking screen: small logo + "GPS Tracker"
/// title + logout icon. Transparent background so the screen's cream
/// colour shows through.
class TrackingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onLogout;

  const TrackingAppBar({super.key, required this.onLogout});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHPadding,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            const AppLogo(size: 36),
            const SizedBox(width: AppSpacing.md),
            Text('GPS Tracker', style: AppTextStyles.h3),
            const Spacer(),
            GestureDetector(
              onTap: onLogout,
              child: Image.asset("assets/icons/logout_icon.png",
                  height: 24,
                  width: 24,))
            // IconButton(
            //   onPressed: onLogout,
            //   tooltip: 'Sign out',
            //   icon: const Icon(
            //     Icons.logout_rounded,
            //     color: AppColors.primaryRed,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
