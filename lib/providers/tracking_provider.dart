import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/errors/domain_error.dart';
import '../models/auth_status.dart';
import '../models/location_point.dart';
import '../models/session_summary.dart';
import '../models/tracking_session.dart';
import '../models/tracking_ui_state.dart';
import '../repositories/location_repository.dart';
import '../repositories/tracking_repository.dart';
import '../services/location_service.dart';
import 'auth_provider.dart';
import 'connectivity_provider.dart';

/// Rough size-on-the-wire per point. Used to turn the queue's item
/// count into the "128 KB of 400 KB" progress copy from the Figma —
/// exact bytes don't matter, relative progress does.
const int _kEstBytesPerPoint = 128;

// --- Internal composite state axes ------------------------------------------

sealed class _SessionPhase {
  const _SessionPhase();
}

class _SessionNone extends _SessionPhase {
  const _SessionNone();
}

class _SessionStarting extends _SessionPhase {
  const _SessionStarting();
}

class _SessionActive extends _SessionPhase {
  final TrackingSession session;
  const _SessionActive(this.session);
}

class _SessionStopping extends _SessionPhase {
  const _SessionStopping();
}

sealed class _SyncPhase {
  const _SyncPhase();
}

class _SyncIdle extends _SyncPhase {
  const _SyncIdle();
}

class _SyncFlushing extends _SyncPhase {
  final int bytesSent;
  final int bytesTotal;
  const _SyncFlushing(this.bytesSent, this.bytesTotal);
}

class _SyncFailed extends _SyncPhase {
  final DateTime at;
  const _SyncFailed(this.at);
}

// --- Provider ---------------------------------------------------------------

/// Central orchestrator for the tracking screen.
///
/// Holds four independent internal state axes — session phase, sync
/// phase, auth status (from [AuthProvider]), connectivity (from
/// [ConnectivityProvider]) — and derives one [TrackingUiState] for the
/// UI via [uiState]. The priority order matches
/// `ARCHITECTURE.md §2.4.4`.
class TrackingProvider extends ChangeNotifier {
  final TrackingRepository _trackingRepo;
  final LocationRepository _locationRepo;
  final LocationService _locationService;
  final AuthProvider _auth;
  final ConnectivityProvider _connectivity;

  _SessionPhase _session = const _SessionNone();
  _SyncPhase _sync = const _SyncIdle();
  SessionSummary? _lastActivity;
  DateTime? _lastSyncAt;
  int _queuedCount = 0;

  StreamSubscription<LocationPoint>? _locationSub;
  bool _wasOnline = true;
  LocationPoint? _lastPoint;

  TrackingProvider({
    required TrackingRepository trackingRepo,
    required LocationRepository locationRepo,
    required LocationService locationService,
    required AuthProvider auth,
    required ConnectivityProvider connectivity,
  })  : _trackingRepo = trackingRepo,
        _locationRepo = locationRepo,
        _locationService = locationService,
        _auth = auth,
        _connectivity = connectivity {
    _wasOnline = connectivity.online;
    _auth.addListener(_onAuthChanged);
    _connectivity.addListener(_onConnectivityChanged);
  }

  // --- Derived UI state -----------------------------------------------------

  TrackingUiState get uiState {
    // 1. Session expired beats everything — user must re-auth.
    if (_auth.status == AuthStatus.expired) {
      return TrackingSessionExpired(_lastSyncAt ?? DateTime.now());
    }

    // 1b. Session is starting (permissions + API call in flight).
    if (_session is _SessionStarting) {
      return const TrackingInitializing();
    }

    // 2. Sync failed takes over the screen. Show the most recent
    //    *successful* sync time when available — that's what "Last
    //    sync" means to the user. Fall back to the failure time only
    //    if there's never been a successful sync yet.
    final sync = _sync;
    if (sync is _SyncFailed) {
      return TrackingSyncFailed(_lastSyncAt ?? sync.at);
    }

    // 3. Flushing while no active session -> dedicated Syncing screen.
    final session = _session;
    if (sync is _SyncFlushing && session is! _SessionActive) {
      return TrackingSyncing(
        bytesSent: sync.bytesSent,
        bytesTotal: sync.bytesTotal,
      );
    }

    // 4. Active session.
    if (session is _SessionActive) {
      return TrackingActive(
        session: session.session,
        isOffline: !_connectivity.online,
        queuedCount: _queuedCount,
      );
    }

    // 5. Default: Idle.
    return TrackingIdle(
      lastActivity: _lastActivity,
      isOffline: !_connectivity.online,
    );
  }

  // --- Intents from UI ------------------------------------------------------

  Future<void> startTracking() async {
    if (_session is! _SessionNone) return;

    _session = const _SessionStarting();
    notifyListeners();

    try {
      final hasPermission = await _locationService.ensurePermissions();
      if (!hasPermission) {
        _session = const _SessionNone();
        notifyListeners();
        return;
      }

      final created = await _trackingRepo.openSession();
      _session = _SessionActive(created);
      _lastPoint = null;
      await _locationService.start();
      _locationSub = _locationService.stream.listen(_onLocation);
      notifyListeners();
    } catch (_) {
      _session = const _SessionNone();
      notifyListeners();
    }
  }

  Future<void> stopTracking() async {
    final current = _session;
    if (current is _SessionNone || current is _SessionStopping) return;

    _session = const _SessionStopping();
    notifyListeners();

    await _locationSub?.cancel();
    _locationSub = null;
    await _locationService.stop();
    _lastPoint = null;

    if (current is _SessionActive) {
      try {
        await _trackingRepo.closeSession(current.session.id);
      } on DomainError {
        // Non-fatal — user already tapped Stop, don't block the UX on it.
      }

      _lastActivity = SessionSummary(
        name: current.session.activityName ?? 'Activity',
        distanceMeters: current.session.distanceMeters,
        duration: current.session.duration,
      );
    }
    _session = const _SessionNone();
    notifyListeners();

    // Drain any remaining queued points now that we're idle.
    await _maybeFlush();
  }

  Future<void> retrySync() async {
    // Still offline — keep the SyncFailed screen visible. Without
    // this guard, resetting to idle would briefly flicker the user to
    // the Idle screen (because _maybeFlush returns early when offline)
    // and never come back to Sync failed.
    if (!_connectivity.online) return;

    _sync = const _SyncIdle();
    notifyListeners();
    await _maybeFlush();
  }

  // --- Internal wiring ------------------------------------------------------

  Future<void> _onLocation(LocationPoint point) async {
    final current = _session;
    if (current is! _SessionActive) return;

    var session = current.session;
    final last = _lastPoint;
    if (last != null) {
      final segment = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        point.latitude,
        point.longitude,
      );
      session = session.copyWith(
        distanceMeters: session.distanceMeters + segment,
      );
    }
    session = session.copyWith(
      duration: DateTime.now().difference(session.startedAt),
    );
    _session = _SessionActive(session);
    _lastPoint = point;

    await _locationRepo.enqueue(
      trackingSessionId: session.id,
      point: point,
    );
    _queuedCount = await _locationRepo.pendingCount();

    // Don't flush mid-tracking — points accumulate locally and drain
    // when the user taps Stop. This matches the Figma flow where the
    // Syncing screen only appears after the session ends.
    notifyListeners();
  }

  /// Minimum time the Syncing card stays on screen, even if the actual
  /// upload finishes faster. Without this the card can flash for a few
  /// frames and the user never sees the progress indicator.
  static const Duration _kMinSyncVisible = Duration(seconds: 2);

  Future<void> _maybeFlush() async {
    if (_sync is _SyncFlushing) return;
    if (!_connectivity.online) return;

    final count = await _locationRepo.pendingCount();
    if (count == 0) return;

    _sync = _SyncFlushing(0, count * _kEstBytesPerPoint);
    notifyListeners();

    final startedAt = DateTime.now();

    try {
      await _locationRepo.flush(
        onProgress: (sent, total) {
          _sync = _SyncFlushing(
            sent * _kEstBytesPerPoint,
            total * _kEstBytesPerPoint,
          );
          notifyListeners();
        },
      );

      _lastSyncAt = DateTime.now();
      _queuedCount = 0;

      // Hold the syncing card on screen for at least _kMinSyncVisible.
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < _kMinSyncVisible) {
        await Future.delayed(_kMinSyncVisible - elapsed);
      }

      _sync = const _SyncIdle();
      notifyListeners();
    } on DomainError {
      _sync = _SyncFailed(DateTime.now());
      notifyListeners();
    }
  }

  void _onAuthChanged() {
    // If we lost the session (expired or logout) while tracking, stop
    // cleanly so we don't keep draining GPS in the background.
    if (_auth.status != AuthStatus.authenticated &&
        _session is _SessionActive) {
      _locationSub?.cancel();
      _locationSub = null;
      _locationService.stop();
      _session = const _SessionNone();
    }
    // Re-login resets any stale expired/failed sync state.
    if (_auth.status == AuthStatus.authenticated &&
        _sync is _SyncFailed) {
      _sync = const _SyncIdle();
    }
    notifyListeners();
  }

  void _onConnectivityChanged() {
    final nowOnline = _connectivity.online;
    // Auto-flush on reconnect only when not actively tracking. During
    // a live session we deliberately hold points locally and drain on
    // Stop, so we don't fire the Syncing screen mid-activity.
    if (nowOnline && !_wasOnline && _session is! _SessionActive) {
      unawaited(_maybeFlush());
    }
    _wasOnline = nowOnline;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _connectivity.removeListener(_onConnectivityChanged);
    _locationSub?.cancel();
    super.dispose();
  }
}
