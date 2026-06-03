import 'package:flutter/material.dart';

/// Brand palette — exact hex values from the approved Figma Color Guide.
///
/// The five brand colors are:
///   #D84522  primary red       (titles, primary CTAs)
///   #E26629  orange accent     (subtitles / soft text)
///   #69B197  teal              (secondary actions, pin)
///   #F0A03E  card orange       (stats / sync cards)
///   #F8EBC1  cream             (app background)
class AppColors {
  AppColors._();

  // Surfaces
  static const Color backgroundCream = Color(0xFFF8EBC1);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color cardOrange = Color(0xFFF0A03E);
  static const Color alertTint = Color(0xFFF5C38A);

  // Brand accents
  static const Color primaryRed = Color(0xFFD84522);
  static const Color secondaryTeal = Color(0xFF69B197);

  // Text
  static const Color textStrong = Color(0xFFD84522); // Titles (red family)
  static const Color textSoft = Color(0xFFE26629);   // Subtitles (orange)
  static const Color textOnOrangeStrong = Color(0xFFD84522);
  static const Color textOnOrangeSoft = Color(0xFFF8EBC1);
  static const Color textOnDark = Color(0xFF3A2A1A);

  // States
  static const Color disabled = Color(0x66D84522); // 40% primary
}
