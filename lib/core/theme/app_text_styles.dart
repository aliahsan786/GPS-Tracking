import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography scale from the PDF design doc (page 1).
///
/// Font sources:
///   H1, H2   -> Oswald Bold
///   H3..Body -> Montserrat
///
/// Using `google_fonts` for zero-config dev. For production, bundle the
/// TTFs in `assets/fonts/` and declare them in `pubspec.yaml` to remove
/// the first-run network fetch.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle h1 = GoogleFonts.oswald(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: AppColors.textStrong,
    height: 1.1,
  );

  static TextStyle h2 = GoogleFonts.oswald(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textStrong,
    height: 1.15,
  );

  static TextStyle h3 = GoogleFonts.montserrat(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textStrong,
  );

  static TextStyle h4 = GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textStrong,
  );

  static TextStyle button = GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.surfaceWhite,
  );

  static TextStyle body1 = GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textStrong,
  );

  static TextStyle body2 = GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSoft,
  );

  static TextStyle body3 = GoogleFonts.montserrat(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSoft,
  );

  // Convenience variants
  static TextStyle label = GoogleFonts.montserrat(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.textOnOrangeSoft,
  );
}
