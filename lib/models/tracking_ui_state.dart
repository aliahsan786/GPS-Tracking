import 'session_summary.dart';
import 'tracking_session.dart';

/// The single UI-facing state for the tracking screen.
///
/// Derived by [TrackingProvider] (when wired) from its internal
/// composite state. Screens should only ever switch/match on this
/// sealed class — never on raw booleans like `isSyncing`.
///
/// Priority (first match wins), recorded here to keep screen and
/// provider aligned:
///   1. authStatus  == expired    -> [TrackingSessionExpired]
///   2. syncStatus  == failed     -> [TrackingSyncFailed]
///   3. syncStatus  == flushing
///      && no active session      -> [TrackingSyncing]
///   4. sessionStatus == active   -> [TrackingActive]
///   5. default                   -> [TrackingIdle]
sealed class TrackingUiState {
  const TrackingUiState();
}

class TrackingInitializing extends TrackingUiState {
  const TrackingInitializing();
}

class TrackingIdle extends TrackingUiState {
  final SessionSummary? lastActivity;
  final bool isOffline;
  const TrackingIdle({this.lastActivity, this.isOffline = false});
}

class TrackingActive extends TrackingUiState {
  final TrackingSession session;
  final bool isOffline;
  final int queuedCount;

  const TrackingActive({
    required this.session,
    this.isOffline = false,
    this.queuedCount = 0,
  });
}

class TrackingSyncing extends TrackingUiState {
  final int bytesSent;
  final int bytesTotal;

  const TrackingSyncing({
    required this.bytesSent,
    required this.bytesTotal,
  });

  double get percent => bytesTotal == 0 ? 0 : bytesSent / bytesTotal;
}

class TrackingSyncFailed extends TrackingUiState {
  final DateTime lastSyncAt;
  const TrackingSyncFailed(this.lastSyncAt);
}

class TrackingSessionExpired extends TrackingUiState {
  final DateTime lastSyncAt;
  const TrackingSessionExpired(this.lastSyncAt);
}
