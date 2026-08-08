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

  /// Opens the standalone Dashboard web page (always available alongside
  /// the Start/Stop control).
  final VoidCallback onDashboard;

  const TrackingScreen({
    super.key,
    required this.state,
    required this.onStartTracking,
    required this.onStopTracking,
    required this.onRetrySync,
    required this.onLoginAgain,
    required this.onLogout,
    required this.onDashboard,
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
        onDashboard: onDashboard,
      ),
      TrackingIdle(:final isOffline) => _IdleBody(
        isOffline: isOffline,
        onStart: onStartTracking,
        onDashboard: onDashboard,
      ),
      TrackingActive(:final isOffline) => _ActiveBody(
        isOffline: isOffline,
        onStop: onStopTracking,
        onDashboard: onDashboard,
      ),
      TrackingSyncing(:final bytesSent, :final bytesTotal) => _SyncingBody(
        bytesSent: bytesSent,
        bytesTotal: bytesTotal,
        onDashboard: onDashboard,
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

/// Bottom action row: the Start/Stop control on the left and the Dashboard
/// button on the right, equal width. Dashboard is always present.
class _BottomActions extends StatelessWidget {
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback onDashboard;

  const _BottomActions({
    required this.primaryLabel,
    required this.onPrimary,
    required this.onDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PrimaryButton(label: primaryLabel, onPressed: onPrimary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: PrimaryButton(
            label: 'Dashboard',
            onPressed: onDashboard,
            variant: PrimaryButtonVariant.teal,
          ),
        ),
      ],
    );
  }
}

/// S_Init — Initializing (permissions + session creation in flight)
class _InitializingBody extends StatelessWidget {
  final VoidCallback onStop;
  final VoidCallback onDashboard;

  const _InitializingBody({required this.onStop, required this.onDashboard});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _PinAndStatus(
            label: 'Initializing Portal',
            subtitle:
                'Securely connecting to synchronisation\nnode. Verifying satellite handshake.',
            pinColor: AppColors.cardOrange,
            pinIcon: Icons.language_rounded,
          ),
        ),
        _BottomActions(
          primaryLabel: 'Stop Tracking',
          onPrimary: onStop,
          onDashboard: onDashboard,
        ),
      ],
    );
  }
}

/// S4 — Idle
class _IdleBody extends StatelessWidget {
  final bool isOffline;
  final VoidCallback onStart;
  final VoidCallback onDashboard;

  const _IdleBody({
    required this.isOffline,
    required this.onStart,
    required this.onDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(child: _PinAndStatus(label: 'Tracking is off')),
        if (isOffline) ...[
          const AlertBanner(
            icon: Icons.wifi_off_rounded,
            title: 'No internet connection',
            subtitle: 'Saving location data locally until reconnected.',
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _BottomActions(
          primaryLabel: 'Start Tracking',
          onPrimary: isOffline ? null : onStart,
          onDashboard: onDashboard,
        ),
      ],
    );
  }
}

/// S7 — Active (with optional offline banner)
class _ActiveBody extends StatelessWidget {
  final bool isOffline;
  final VoidCallback onStop;
  final VoidCallback onDashboard;

  const _ActiveBody({
    required this.isOffline,
    required this.onStop,
    required this.onDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(child: _PinAndStatus(label: 'Tracking in progress')),
        if (isOffline) ...[
          const AlertBanner(
            icon: Icons.wifi_off_rounded,
            title: 'No internet connection',
            subtitle: 'Saving location data locally until reconnected.',
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _BottomActions(
          primaryLabel: 'Stop Tracking',
          onPrimary: onStop,
          onDashboard: onDashboard,
        ),
      ],
    );
  }
}

/// S5 — Syncing
class _SyncingBody extends StatelessWidget {
  final int bytesSent;
  final int bytesTotal;
  final VoidCallback onDashboard;

  const _SyncingBody({
    required this.bytesSent,
    required this.bytesTotal,
    required this.onDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SyncProgressCard(bytesSent: bytesSent, bytesTotal: bytesTotal),
        const Spacer(),
        // Start is disabled while a flush is in flight; Dashboard stays on.
        _BottomActions(
          primaryLabel: 'Start Tracking',
          onPrimary: null,
          onDashboard: onDashboard,
        ),
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
            Icon(
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

  /// Null defaults to the themed teal (resolved at build time, since
  /// theme colors are non-const).
  final Color? pinColor;
  final IconData pinIcon;

  const _PinAndStatus({
    required this.label,
    this.subtitle,
    this.pinColor,
    this.pinIcon = Icons.location_on_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PulsingPin(
          size: 140,
          color: pinColor ?? AppColors.secondaryTeal,
          icon: pinIcon,
        ),
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
