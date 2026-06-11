import 'dart:async';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

import '../core/config/env.dart';
import '../models/location_point.dart';

/// GPS position stream with platform-appropriate background config.
///
/// Android: uses [AndroidSettings] with a [ForegroundNotificationConfig]
/// so the OS keeps us alive while the screen is off. This implicitly
/// starts an Android foreground service — no separate package needed.
///
/// iOS: [AppleSettings] with `allowBackgroundLocationUpdates: true`.
/// The app's Info.plist must also declare `UIBackgroundModes: location`.
abstract class LocationService {
  /// Emits a [LocationPoint] every time the OS delivers a fresh fix.
  /// Broadcast, so multiple listeners are safe.
  Stream<LocationPoint> get stream;

  /// Checks service + permissions, prompting when possible. Returns true
  /// only if the app can stream positions right now.
  Future<bool> ensurePermissions();

  Future<void> start();
  Future<void> stop();

  Future<void> dispose();
}

class LocationServiceImpl implements LocationService {
  /// Target cadence for GPS fixes. Sourced from the remote theme
  /// (`tracking_interval_seconds`) at startup; falls back to [Env].
  final Duration interval;

  LocationServiceImpl({Duration? interval})
      : interval = interval ?? Env.locationInterval;

  final StreamController<LocationPoint> _controller =
      StreamController<LocationPoint>.broadcast();
  StreamSubscription<Position>? _subscription;

  @override
  Stream<LocationPoint> get stream => _controller.stream;

  @override
  Future<bool> ensurePermissions() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return false;
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  @override
  Future<void> start() async {
    await _subscription?.cancel();

    _subscription = Geolocator.getPositionStream(
      locationSettings: _buildSettings(),
    ).listen(
      (pos) => _controller.add(LocationPoint(
        latitude: pos.latitude,
        longitude: pos.longitude,
        timestamp: pos.timestamp,
        accuracy: pos.accuracy,
      )),
      onError: _controller.addError,
    );
  }

  @override
  Future<void> stop() async {
    try {
      await _subscription?.cancel();
    } catch (_) {
      // Native side can throw "No active stream to cancel" if the
      // underlying location stream already errored out. Safe to ignore.
    }
    _subscription = null;
  }

  LocationSettings _buildSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: interval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'GPS Tracker',
          notificationText: 'Tracking your activity',
          enableWakeLock: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: false,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high);
  }

  @override
  Future<void> dispose() async {
    try {
      await _subscription?.cancel();
    } catch (_) {/* ignore — see [stop]. */}
    _subscription = null;
    await _controller.close();
  }
}
