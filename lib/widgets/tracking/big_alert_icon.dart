import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The large red alert circle shown on SyncFailed (S6) and
/// SessionExpired (S8) states. Radial fade, no animation.
class BigAlertIcon extends StatelessWidget {
  final double size;
  const BigAlertIcon({super.key, this.size = 140});

  @override
  Widget build(BuildContext context) {
    // final red = AppColors.primaryRed;
    return SizedBox(
      width: size,
      height: size,
      child: 
      Image.asset("assets/icons/sync_failed_icon.png",width: 100,height: 100,
      )
      // Stack(
      //   alignment: Alignment.center,
      //   children: [
      //     _ring(size, red.withValues(alpha: 0.10)),
      //     _ring(size * 0.7, red.withValues(alpha: 0.18)),
      //     _ring(size * 0.45, red),
      //     Icon(
      //       Icons.priority_high_rounded,
      //       color: AppColors.surfaceWhite,
      //       size: size * 0.25,
      //     ),
      //   ],
      // ),
    
    );
  }

  // Widget _ring(double d, Color c) => Container(
  //       width: d,
  //       height: d,
  //       decoration: BoxDecoration(shape: BoxShape.circle, color: c),
  //     );
}
