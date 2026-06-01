import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../models/location_point.dart';

/// A single queued entry: a location point tagged with the tracking
/// session it belongs to.
class QueuedPoint {
  final String trackingSessionId;
  final LocationPoint point;

  const QueuedPoint({
    required this.trackingSessionId,
    required this.point,
  });

  Map<String, dynamic> toJson() => {
        'tracking_session_id': trackingSessionId,
        'point': point.toJson(),
      };

  factory QueuedPoint.fromJson(Map<String, dynamic> json) => QueuedPoint(
        trackingSessionId: json['tracking_session_id'] as String,
        point: LocationPoint.fromJson(json['point'] as Map<String, dynamic>),
      );
}

/// Persistent FIFO queue for location points captured while offline (or
/// any other time the ingest POST fails).
///
/// We use Hive with a `Box<String>` of JSON blobs to avoid generating
/// TypeAdapters — keeps the build simple. FIFO is preserved by Hive's
/// monotonic auto-increment keys (`box.add(...)`).
abstract class LocalQueueService {
  /// Must be called once at app startup, after `Hive.initFlutter()`.
  Future<void> init();

  Future<void> enqueue(QueuedPoint item);

  /// Returns up to [limit] oldest items without removing them. Caller
  /// removes via [removeFirst] after a successful upload.
  Future<List<QueuedPoint>> peek({int limit = 50});

  /// Removes the oldest [count] items. Used after a successful flush.
  Future<void> removeFirst(int count);

  Future<int> size();
  Future<void> clear();
}

class LocalQueueServiceImpl implements LocalQueueService {
  static const _boxName = 'pending_location_points';
  Box<String>? _box;

  @override
  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  Box<String> get _require {
    final box = _box;
    if (box == null) {
      throw StateError('LocalQueueService.init() was not called');
    }
    return box;
  }

  @override
  Future<void> enqueue(QueuedPoint item) async {
    await _require.add(jsonEncode(item.toJson()));
  }

  @override
  Future<List<QueuedPoint>> peek({int limit = 50}) async {
    final box = _require;
    final keys = box.keys.take(limit).toList();
    final out = <QueuedPoint>[];
    for (final key in keys) {
      final raw = box.get(key);
      if (raw == null) continue;
      out.add(QueuedPoint.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      ));
    }
    return out;
  }

  @override
  Future<void> removeFirst(int count) async {
    final box = _require;
    final keys = box.keys.take(count).toList();
    await box.deleteAll(keys);
  }

  @override
  Future<int> size() async => _require.length;

  @override
  Future<void> clear() async => _require.clear();
}
