/// Holds the remote brand asset URLs (logo + background) supplied by the
/// theme endpoint. Populated once at startup via [applyTheme], read by
/// [AppLogo] and [TrackingBackground].
///
/// When a URL is null the widgets fall back to their bundled asset, so the
/// app still renders before the network call resolves (or if it fails).
class AppRemoteAssets {
  AppRemoteAssets._();

  static String? _logoUrl;
  static String? _backgroundUrl;

  static String? get logoUrl => _logoUrl;
  static String? get backgroundUrl => _backgroundUrl;

  static void applyTheme({String? logoUrl, String? backgroundUrl}) {
    if (logoUrl != null && logoUrl.isNotEmpty) _logoUrl = logoUrl;
    if (backgroundUrl != null && backgroundUrl.isNotEmpty) {
      _backgroundUrl = backgroundUrl;
    }
  }
}
