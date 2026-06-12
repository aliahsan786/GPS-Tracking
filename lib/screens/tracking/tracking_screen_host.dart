import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../models/theme_config.dart';
import '../../models/tracking_ui_state.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../services/secure_storage_service.dart';
import 'tracking_screen.dart';
import 'tracking_webview_screen.dart';

/// State adapter for [TrackingScreen].
///
/// Subscribes to [TrackingProvider.uiState] via a [Selector] so the
/// screen only rebuilds when the derived UI state actually changes —
/// not on every internal mutation (sync progress ticks, queue count
/// updates, etc.) that happens to call `notifyListeners`.
class TrackingScreenHost extends StatelessWidget {
  const TrackingScreenHost({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<TrackingProvider, TrackingUiState>(
      selector: (_, p) => p.uiState,
      builder: (ctx, state, __) {
        // Use read (not watch) for callbacks — we don't need to rebuild
        // when the method references change.
        final tracking = ctx.read<TrackingProvider>();
        return TrackingScreen(
          state: state,
          onStartTracking: () => _startThenOpenWebView(ctx, tracking),
          onStopTracking: tracking.stopTracking,
          onRetrySync: tracking.retrySync,
          onLoginAgain: () => _logoutToLogin(ctx),
          onLogout: () => _logoutToLogin(ctx),
        );
      },
    );
  }

  /// Runs the normal start flow (permissions + open session + GPS stream).
  /// If it succeeds (session becomes active) and a web portal URL is
  /// configured, opens the web portal on top with a Stop button. Stopping
  /// there runs the normal stop flow and returns to this screen.
  Future<void> _startThenOpenWebView(
    BuildContext context,
    TrackingProvider tracking,
  ) async {
    await tracking.startTracking();
    if (!context.mounted) return;

    // Permission denied or session failed -> stay on the tracking screen.
    if (tracking.uiState is! TrackingActive) return;

    final baseUrl = context.read<ThemeConfig>().webviewStartUrl;
    if (baseUrl == null || baseUrl.isEmpty) return; // no portal configured

    // The web portal (session bridge) needs the logged-in session to
    // authenticate inside the WebView, so append the session token to the
    // JSON-provided URL: <webview_start_url>?session_token=<token>.
    final storage = context.read<SecureStorageService>();
    final token = await storage.readSessionToken();
    if (!context.mounted) return;

    final url = _withSessionToken(baseUrl, token);
    debugPrint('[webview] opening portal: $url');

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackingWebViewScreen(
          url: url,
          onStop: tracking.stopTracking,
        ),
      ),
    );
  }

  /// Appends `session_token=<token>` to [base] as a query parameter,
  /// merging safely if the URL already has a query string. Returns [base]
  /// unchanged when there's no token.
  String _withSessionToken(String base, String? token) {
    if (token == null || token.isEmpty) return base;
    final uri = Uri.parse(base);
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'session_token': token,
      },
    ).toString();
  }

  Future<void> _logoutToLogin(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }
}
