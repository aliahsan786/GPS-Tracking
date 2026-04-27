import 'package:intl/intl.dart';

/// Human-readable formatters shared across the UI. Pure functions, no
/// state — safe to call from anywhere.
class Formatters {
  Formatters._();

  /// e.g. `12.4 km`, `850 m`. Keeps UI consistent whether the backend
  /// sends small or long distances.
  static String distance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 2 : 1)} km';
  }

  /// e.g. `2h 14m`, `47m`, `45s`. No leading zeros for hours.
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${s}s';
  }

  /// e.g. `7:17:28 PM`. Used in "Last sync" banners.
  static String clockTime(DateTime t) =>
      DateFormat.jms().format(t.toLocal());

  /// e.g. `128 KB`. Used in the sync progress card.
  static String bytes(int b) {
    if (b < 1024) return '$b B';
    final kb = b / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
