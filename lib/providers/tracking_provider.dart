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

  /// Cadence for live transmission while tracking is active. Sourced from
  /// the remote theme (`tracking_interval_seconds`).
  final Duration _liveInterval;

  _SessionPhase _session = const _SessionNone();
  _SyncPhase _sync = const _SyncIdle();
  SessionSummary? _lastActivity;
  DateTime? _lastSyncAt;
  int _queuedCount = 0;

  StreamSubscription<LocationPoint>? _locationSub;
  bool _wasOnline = true;
  LocationPoint? _lastPoint;

  /// Periodic driver that pushes queued points to the server every
  /// [_liveInterval] while a session is active.
  Timer? _liveTimer;

  /// Reentrancy guard for [_liveFlush] so overlapping ticks (timer + new
  /// point + reconnect) don't double-send.
  bool _liveFlushing = false;

  /// Counts heartbeat ticks within the current session (for the cadence
  /// log). Reset to 0 each time a session starts.
  int _heartbeatTick = 0;

  TrackingProvider({
    required TrackingRepository trackingRepo,
    required LocationRepository locationRepo,
    required LocationService locationService,
    required AuthProvider auth,
    required ConnectivityProvider connectivity,
    Duration? liveInterval,
  })  : _trackingRepo = trackingRepo,
        _locationRepo = locationRepo,
        _locationService = locationService,
        _auth = auth,
        _connectivity = connectivity,
        _liveInterval = _resolveInterval(liveInterval) {
    _wasOnline = connectivity.online;
    _auth.addListener(_onAuthChanged);
    _connectivity.addListener(_onConnectivityChanged);
  }

  /// Guards against a missing or non-positive interval (which would make
  /// `Timer.periodic` fire continuously). Falls back to 5s.
  static Duration _resolveInterval(Duration? d) =>
      (d == null || d.inSeconds < 1) ? const Duration(seconds: 5) : d;

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
      // Heartbeat: every [_liveInterval] grab the current location and
      // send it (same point or not). This is the live-tracking driver —
      // transmission is timer-paced, not per-GPS-fix.
      debugPrint('[tracking] live heartbeat started — every '
          '${_liveInterval.inSeconds}s (from theme)');
      _heartbeatTick = 0;
      _liveTimer?.cancel();
      _liveTimer = Timer.periodic(_liveInterval, (_) => unawaited(_heartbeat()));
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

    // Stop the live driver and GPS first so nothing new enqueues.
    _liveTimer?.cancel();
    _liveTimer = null;
    await _locationSub?.cancel();
    _locationSub = null;
    await _locationService.stop();
    _lastPoint = null;

    if (current is _SessionActive) {
      // Per the live-tracking contract: upload any remaining unsent points
      // BEFORE closing the session. Best-effort — if offline, points stay
      // queued and drain later via _maybeFlush / on reconnect.
      await _liveFlush();

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
    // The GPS stream only keeps the *current* location fresh (and drives
    // the on-screen distance/time). Transmission is NOT per-fix — it's the
    // fixed N-second [_heartbeat]. See the heartbeat for the actual send.
    _lastPoint = point;
    notifyListeners();
  }

  /// Heartbeat: every [_liveInterval], take the current location and send
  /// it to the server — whether or not it changed since the last tick.
  ///
  /// The point is enqueued first (durable buffer that survives offline /
  /// app death), then [_liveFlush] transmits. While online and caught up
  /// this is one POST per tick (the latest location). While offline the
  /// queue grows one point per tick and is replayed oldest-first on
  /// reconnect.
  Future<void> _heartbeat() async {
    final current = _session;
    if (current is! _SessionActive) return;

    _heartbeatTick++;
    final elapsed = _heartbeatTick * _liveInterval.inSeconds;
    debugPrint('━━━━━━━━━━━━━━━ ${_liveInterval.inSeconds}s tick '
        '#$_heartbeatTick · ${elapsed}s elapsed ━━━━━━━━━━━━━━━');

    final point = _lastPoint; // most recent GPS fix = current location
    if (point == null) {
      debugPrint('[tracking] tick #$_heartbeatTick — no GPS fix yet, skipping');
      return; // no fix yet — wait for the next tick
    }

    debugPrint('[tracking] tick #$_heartbeatTick → queueing current location');
    await _locationRepo.enqueue(
      trackingSessionId: current.session.id,
      point: point,
    );
    _queuedCount = await _locationRepo.pendingCount();
    notifyListeners();

    unawaited(_liveFlush());
  }

  /// Sends queued points to the server **during an active session**,
  /// oldest-first (chronological). Unlike [_maybeFlush] this never shows
  /// the full-screen Syncing UI — tracking stays visible — and on failure
  /// it simply leaves the points queued to retry on the next tick or
  /// reconnect. No-op when offline or already flushing.
  Future<void> _liveFlush() async {
    if (_liveFlushing) return;
    if (!_connectivity.online) return;
    _liveFlushing = true;
    try {
      await _locationRepo.flush();
      _queuedCount = await _locationRepo.pendingCount();
      _lastSyncAt = DateTime.now();
      notifyListeners();
    } on DomainError {
      // Transient (network/server) — keep points queued; retry later.
    } finally {
      _liveFlushing = false;
    }
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
      _liveTimer?.cancel();
      _liveTimer = null;
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
    if (nowOnline && !_wasOnline) {
      if (_session is _SessionActive) {
        // Back online mid-session: upload the points missed while offline,
        // oldest-first, then resume normal live transmission. No Syncing
        // screen — tracking stays visible.
        unawaited(_liveFlush());
      } else {
        // Idle: drain any leftover queue with the Syncing UI.
        unawaited(_maybeFlush());
      }
    }
    _wasOnline = nowOnline;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _connectivity.removeListener(_onConnectivityChanged);
    _liveTimer?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }
}
