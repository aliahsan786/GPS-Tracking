import '../core/config/env.dart';
import '../core/constants/api_paths.dart';
import '../models/location_point.dart';
import '../services/api_client.dart';
import '../services/local_queue_service.dart';

/// Owns the online/offline ingest path for location points.
///
/// The backend endpoint (`api_tracking_location.php`) accepts **one
/// point per POST** — not a batch — so the flush loop sends one at a
/// time and reports progress after each success. If batching becomes
/// available later, this is the only file that needs to change.
///
/// Payload shape (per the backend curl spec):
/// ```json
/// {
///   "session_token": "...",      // injected by ApiClient
///   "tracking_session_id": "...",
///   "lat":  40.7128,
///   "lng": -74.0060,
///   "timestamp": 1713880000,     // unix seconds (UTC)
///   "accuracy": 5
/// }
/// ```
abstract class LocationRepository {
  Future<void> enqueue({
    required String trackingSessionId,
    required LocationPoint point,
  });

  Future<int> pendingCount();

  /// Drains the queue one point at a time. Reports `(sent, total)`
  /// where totals are counts, not bytes — the provider converts.
  /// Throws `DomainError` on the first failing POST; already-sent
  /// points remain removed from the queue.
  Future<void> flush({
    int batchSize,
    void Function(int sent, int total)? onProgress,
  });
}

class LocationRepositoryImpl implements LocationRepository {
  final ApiClient _api;
  final LocalQueueService _queue;

  /// Reentrancy guard. Connectivity-restored and manual-retry can
  /// collide otherwise and double-delete from the queue.
  bool _flushing = false;

  LocationRepositoryImpl(this._api, this._queue);

  @override
  Future<void> enqueue({
    required String trackingSessionId,
    required LocationPoint point,
  }) async {
    await _queue.enqueue(QueuedPoint(
      trackingSessionId: trackingSessionId,
      point: point,
    ));
  }

  @override
  Future<int> pendingCount() => _queue.size();

  @override
  Future<void> flush({
    int batchSize = Env.flushBatchSize, // kept for API compatibility; unused.
    void Function(int sent, int total)? onProgress,
  }) async {
    if (_flushing) return;
    _flushing = true;

    try {
      final total = await _queue.size();
      if (total == 0) {
        onProgress?.call(0, 0);
        return;
      }

      int sent = 0;
      onProgress?.call(sent, total);

      while (true) {
        final next = await _queue.peek(limit: 1);
        if (next.isEmpty) break;
        final q = next.first;

        await _api.post(
          ApiPaths.pointsIngest,
          body: {
            'tracking_session_id': q.trackingSessionId,
            'lat': q.point.latitude,
            'lng': q.point.longitude,
            'timestamp':
                q.point.timestamp.toUtc().millisecondsSinceEpoch ~/ 1000,
            if (q.point.accuracy != null) 'accuracy': q.point.accuracy,
          },
        );

        await _queue.removeFirst(1);
        sent += 1;
        onProgress?.call(sent, total);
      }
    } finally {
      _flushing = false;
    }
  }
}
