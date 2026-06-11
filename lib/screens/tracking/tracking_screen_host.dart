import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../models/theme_config.dart';
import '../../models/tracking_ui_state.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tracking_provider.dart';
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

    final url = context.read<ThemeConfig>().webviewStartUrl;
    if (url == null || url.isEmpty) return; // no portal configured

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackingWebViewScreen(
          url: url,
          onStop: tracking.stopTracking,
        ),
      ),
    );
  }

  Future<void> _logoutToLogin(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }
}
