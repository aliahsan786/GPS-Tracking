import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../models/tracking_ui_state.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tracking_provider.dart';
import 'tracking_screen.dart';

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
      builder: (_, state, __) {
        // Use read (not watch) for callbacks — we don't need to rebuild
        // when the method references change.
        final tracking = context.read<TrackingProvider>();
        return TrackingScreen(
          state: state,
          onStartTracking: tracking.startTracking,
          onPauseTracking: tracking.stopTracking,
          onStopTracking: tracking.stopTracking,
          onRetrySync: tracking.retrySync,
          onLoginAgain: () => _logoutToLogin(context),
          onLogout: () => _logoutToLogin(context),
        );
      },
    );
  }

  Future<void> _logoutToLogin(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }
}
