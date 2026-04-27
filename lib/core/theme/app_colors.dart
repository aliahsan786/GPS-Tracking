import 'package:flutter/material.dart';

/// Brand palette, sampled from the Figma.
///
/// If your designer provides exact hex values in Figma Dev Mode, replace
/// these — they're eyeballed approximations that match the mood of the
/// design but aren't pixel-exact.
class AppColors {
  AppColors._();

  // Surfaces
  static const Color backgroundCream = Color(0xFFFBE9BD);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color cardOrange = Color(0xFFE89938);
  static const Color alertTint = Color(0xFFF5C38A);

  // Brand accents
  static const Color primaryRed = Color(0xFFD94B2A);
  static const Color secondaryTeal = Color(0xFF7FB8A8);

  // Text
  static const Color textStrong = Color(0xFFD94B2A); // Titles (red family)
  static const Color textSoft = Color(0xFFE07A4A);   // Subtitles
  static const Color textOnOrangeStrong = Color(0xFFD94B2A);
  static const Color textOnOrangeSoft = Color(0xFFFBE9BD);
  static const Color textOnDark = Color(0xFF3A2A1A);

  // States
  static const Color disabled = Color(0x66D94B2A); // 40% primary
}
