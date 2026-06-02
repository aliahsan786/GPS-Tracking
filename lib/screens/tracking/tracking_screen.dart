import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/tracking_ui_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/alert_banner.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/tracking/big_alert_icon.dart';
import '../../widgets/tracking/pulsing_pin.dart';
import '../../widgets/tracking/stats_card.dart';
import '../../widgets/tracking/sync_progress_card.dart';
import '../../widgets/tracking/tracking_app_bar.dart';
import '../../widgets/tracking/tracking_background.dart';

/// Single tracking screen that renders one of five variants based on
/// [TrackingUiState]. Purely presentational — no state, no side effects.
///
/// Covers S4 (Idle), S5 (Syncing), S6 (SyncFailed), S7 (Active), S8
/// (SessionExpired).
class TrackingScreen extends StatelessWidget {
  final TrackingUiState state;
  final VoidCallback onStartTracking;
  final VoidCallback onStopTracking;
  final VoidCallback onRetrySync;
  final VoidCallback onLoginAgain;
  final VoidCallback onLogout;

  const TrackingScreen({
    super.key,
    required this.state,
    required this.onStartTracking,
    required this.onStopTracking,
    required this.onRetrySync,
    required this.onLoginAgain,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TrackingBackground(
        child: SafeArea(
          child: Column(
            children: [
              TrackingAppBar(onLogout: onLogout),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHPadding,
                    AppSpacing.sm,
                    AppSpacing.screenHPadding,
                    AppSpacing.lg,
                  ),
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Dart 3 pattern matching — each branch returns a variant-specific
    // body that fills the available vertical space.
    return switch (state) {
      TrackingInitializing() => _InitializingBody(
          onStop: onStopTracking,
        ),
      TrackingIdle(:final lastActivity, :final isOffline) => _IdleBody(
          activityName: lastActivity?.name,
          distance: lastActivity != null
              ? Formatters.distance(lastActivity.distanceMeters)
              : null,
          time: lastActivity != null
              ? Formatters.duration(lastActivity.duration)
              : null,
          isOffline: isOffline,
          onStart: onStartTracking,
        ),
      TrackingActive(
        :final session,
        :final isOffline,
      ) =>
        _ActiveBody(
          activityName: session.activityName,
          distance: Formatters.distance(session.distanceMeters),
          time: Formatters.duration(session.duration),
          isOffline: isOffline,
          onStop: onStopTracking,
        ),
      TrackingSyncing(:final bytesSent, :final bytesTotal) => _SyncingBody(
          bytesSent: bytesSent,
          bytesTotal: bytesTotal,
        ),
      TrackingSyncFailed(:final lastSyncAt) => _AlertBody(
          title: 'Sync failed',
          subtitle: 'Last sync: ${Formatters.clockTime(lastSyncAt)}',
          buttonLabel: 'Retry',
          onPressed: onRetrySync,
        ),
      TrackingSessionExpired(:final lastSyncAt) => _AlertBody(
          title: 'Session expired',
          subtitle: 'Last sync: ${Formatters.clockTime(lastSyncAt)}',
          buttonLabel: 'Login Again',
          onPressed: onLoginAgain,
        ),
    };
  }
}

/// S_Init — Initializing (permissions + session creation in flight)
class _InitializingBody extends StatelessWidget {
  final VoidCallback onStop;

  const _InitializingBody({required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: _PinAndStatus(
            label: 'Initializing Portal',
            subtitle: 'Securely connecting to synchronisation\nnode. Verifying satellite handshake.',
            pinColor: AppColors.cardOrange,
            pinIcon: Icons.language_rounded,
          ),
        ),
        // Design: single full-width Stop button (no Pause).
        PrimaryButton(
          label: 'Stop Tracking',
          onPressed: onStop,
        ),
      ],
    );
  }
}

/// S4 — Idle
class _IdleBody extends StatelessWidget {
  final String? activityName;
  final String? distance;
  final String? time;
  final bool isOffline;
  final VoidCallback onStart;

  const _IdleBody({
    required this.activityName,
    required this.distance,
    required this.time,
    required this.isOffline,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatsCard(
          activityName: activityName,
          distance: distance,
          time: time,
        ),
        const Expanded(child: _PinAndStatus(label: 'Tracking in off')),
        if (isOffline) ...[
          const AlertBanner(
            icon: Icons.wifi_off_rounded,
            title: 'No internet connection',
            subtitle: 'Saving location data locally until reconnected.',
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        PrimaryButton(
          label: 'Start Tracking',
          onPressed: isOffline ? null : onStart,
        ),
      ],
    );
  }
}

/// S7 — Active (with optional offline banner)
class _ActiveBody extends StatelessWidget {
  final String? activityName;
  final String distance;
  final String time;
  final bool isOffline;
  final VoidCallback onStop;

  const _ActiveBody({
    required this.activityName,
    required this.distance,
    required this.time,
    required this.isOffline,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatsCard(
          activityName: activityName ?? 'In progress',
          distance: distance,
          time: time,
        ),
        const Expanded(child: _PinAndStatus(label: 'Tracking in progress')),
        if (isOffline) ...[
          const AlertBanner(
            icon: Icons.wifi_off_rounded,
            title: 'No internet connection',
            subtitle: 'Saving location data locally until reconnected.',
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // Design: a single full-width Stop button (no Pause).
        PrimaryButton(
          label: 'Stop Tracking',
          onPressed: onStop,
        ),
      ],
    );
  }
}

/// S5 — Syncing
class _SyncingBody extends StatelessWidget {
  final int bytesSent;
  final int bytesTotal;

  const _SyncingBody({
    required this.bytesSent,
    required this.bytesTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SyncProgressCard(bytesSent: bytesSent, bytesTotal: bytesTotal),
        const Spacer(),
        // Start button is visible but disabled while a flush is in flight.
        const PrimaryButton(label: 'Start Tracking', onPressed: null),
      ],
    );
  }
}

/// S6 + S8 share the same layout (big red icon + title + subtitle +
/// single CTA at the bottom).
class _AlertBody extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _AlertBody({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(flex: 3),
        const BigAlertIcon(size: 140),
        const SizedBox(height: AppSpacing.xl),
        Text(title, style: AppTextStyles.h2),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 16,
              color: AppColors.textSoft,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(subtitle, style: AppTextStyles.body2),
          ],
        ),
        const Spacer(flex: 4),
        PrimaryButton(label: buttonLabel, onPressed: onPressed),
      ],
    );
  }
}

/// Shared central visual for Idle, Initializing and Active states.
class _PinAndStatus extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Color pinColor;
  final IconData pinIcon;

  const _PinAndStatus({
    required this.label,
    this.subtitle,
    this.pinColor = AppColors.secondaryTeal,
    this.pinIcon = Icons.location_on_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PulsingPin(size: 140, color: pinColor, icon: pinIcon),
        const SizedBox(height: AppSpacing.xl),
        Text(label, style: AppTextStyles.h2),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            style: AppTextStyles.body3,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
