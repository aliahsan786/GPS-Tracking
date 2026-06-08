import 'package:flutter/material.dart';

/// Brand palette — **dynamically themed**.
///
/// The five brand tokens are seeded with baked-in defaults (so the app
/// always renders, even offline / before the network call) and are
/// overwritten at startup from the remote theme endpoint
/// (`app_theme_json.php`) via [applyTheme].
///
/// All public colors are getters that derive from the five mutable base
/// tokens, so updating the base tokens re-themes the whole app. Call
/// [applyTheme] *before* `runApp` so the first frame is already themed.
///
/// API token -> semantic role mapping:
///   primary    -> primaryRed / all red text roles / CTAs
///   secondary  -> secondaryTeal
///   accent     -> cardOrange (stats + sync cards)
///   background -> backgroundCream / cream-on-orange label text
///   text       -> textOnDark (dark body text)
class AppColors {
  AppColors._();

  // --- Mutable base tokens (defaults = current backend values) ---------
  static Color _primary = const Color(0xFFE25327);
  static Color _secondary = const Color(0xFF48BEB4);
  static Color _accent = const Color(0xFFF2BB43);
  static Color _background = const Color(0xFFFAF4DE);
  static Color _text = const Color(0xFF56442A);

  /// Overwrites the base tokens from the remote theme. Any null argument
  /// keeps the existing value.
  static void applyTheme({
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? text,
  }) {
    if (primary != null) _primary = primary;
    if (secondary != null) _secondary = secondary;
    if (accent != null) _accent = accent;
    if (background != null) _background = background;
    if (text != null) _text = text;
  }

  // --- Surfaces --------------------------------------------------------
  static Color get backgroundCream => _background;
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static Color get cardOrange => _accent;

  /// Soft tint behind inline alert banners — a translucent wash of the
  /// accent so it tracks the themed palette.
  static Color get alertTint => Color.alphaBlend(
        _accent.withValues(alpha: 0.35),
        surfaceWhite,
      );

  // --- Brand accents ---------------------------------------------------
  static Color get primaryRed => _primary;
  static Color get secondaryTeal => _secondary;

  // --- Text ------------------------------------------------------------
  static Color get textStrong => _primary; // Titles (red family)
  static Color get textSoft => _primary; // Subtitles / secondary text
  static Color get textOnOrangeStrong => _primary;
  static Color get textOnOrangeSoft => _background;
  static Color get textOnDark => _text;

  // --- States ----------------------------------------------------------
  static Color get disabled => _primary.withValues(alpha: 0.4);
}
