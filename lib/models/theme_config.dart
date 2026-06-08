import 'dart:ui' show Color;

/// Remote theming payload from `GET /app_theme_json.php`.
///
/// Holds the brand colors plus the logo / background image URLs that the
/// app applies at startup. Everything is nullable-tolerant: a missing or
/// malformed field falls back to the baked-in default so the app never
/// renders an unthemed/blank UI.
class ThemeConfig {
  final String themeVersion;

  // Colors (already parsed from "#RRGGBB" hex strings).
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color text;

  // Remote assets. Null when the backend omits them.
  final String? logoUrl;
  final String? backgroundUrl;

  // App config.
  final int trackingIntervalSeconds;

  const ThemeConfig({
    required this.themeVersion,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.text,
    required this.logoUrl,
    required this.backgroundUrl,
    required this.trackingIntervalSeconds,
  });

  /// Parses the API envelope. [defaults] supplies the fallback values for
  /// any field that's missing or unparseable, so this never throws on a
  /// partial payload.
  factory ThemeConfig.fromJson(
    Map<String, dynamic> json, {
    required ThemeConfig defaults,
  }) {
    final colors = json['colors'];
    final assets = json['assets'];
    final app = json['app'];

    Color color(String key, Color fallback) {
      if (colors is! Map) return fallback;
      return parseHexColor(colors[key] as String?) ?? fallback;
    }

    String? url(String key, String? fallback) {
      if (assets is! Map) return fallback;
      final v = assets[key];
      return (v is String && v.isNotEmpty) ? v : fallback;
    }

    return ThemeConfig(
      themeVersion: (json['theme_version'] as String?) ?? defaults.themeVersion,
      primary: color('primary', defaults.primary),
      secondary: color('secondary', defaults.secondary),
      accent: color('accent', defaults.accent),
      background: color('background', defaults.background),
      text: color('text', defaults.text),
      logoUrl: url('logo_url', defaults.logoUrl),
      backgroundUrl: url('background_url', defaults.backgroundUrl),
      trackingIntervalSeconds: (app is Map && app['tracking_interval_seconds'] is int)
          ? app['tracking_interval_seconds'] as int
          : defaults.trackingIntervalSeconds,
    );
  }

  /// Round-trips to the same JSON shape we cache locally.
  Map<String, dynamic> toJson() => {
        'theme_version': themeVersion,
        'colors': {
          'primary': hexFromColor(primary),
          'secondary': hexFromColor(secondary),
          'accent': hexFromColor(accent),
          'background': hexFromColor(background),
          'text': hexFromColor(text),
        },
        'assets': {
          'logo_url': logoUrl,
          'background_url': backgroundUrl,
        },
        'app': {
          'tracking_interval_seconds': trackingIntervalSeconds,
        },
      };

  /// Parses `#RRGGBB` or `#AARRGGBB` (with or without leading `#`).
  /// Returns null when the string is null/empty/invalid.
  static Color? parseHexColor(String? hex) {
    if (hex == null) return null;
    var h = hex.trim().replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h'; // assume opaque
    if (h.length != 8) return null;
    final value = int.tryParse(h, radix: 16);
    if (value == null) return null;
    return Color(value);
  }

  static String hexFromColor(Color c) {
    // ignore: deprecated_member_use
    final argb = c.value & 0xFFFFFFFF;
    final rgb = argb & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
