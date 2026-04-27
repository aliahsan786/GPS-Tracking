import '../core/constants/api_paths.dart';
import '../models/tracking_session.dart';
import '../services/api_client.dart';

/// Lifecycle API for a tracking session. Point ingest lives in
/// [LocationRepository] because it has its own offline/retry concerns.
///
/// Both endpoints expect the session_token in the JSON body — the
/// [ApiClient] auto-injects it, so this repo only supplies the
/// domain-specific fields.
abstract class TrackingRepository {
  Future<TrackingSession> openSession();
  Future<void> closeSession(String id);
}

class TrackingRepositoryImpl implements TrackingRepository {
  final ApiClient _api;
  TrackingRepositoryImpl(this._api);

  @override
  Future<TrackingSession> openSession() async {
    final data = await _api.post(ApiPaths.sessionsStart);

    // Mock + future real backend both use `tracking_session_id`; fall
    // back to `id` for defensive compatibility with other shapes.
    final id = (data['tracking_session_id'] as String?) ??
        (data['id'] as String?);
    if (id == null) {
      throw StateError(
        'tracking start response missing tracking_session_id',
      );
    }

    final rawStartedAt = data['started_at'];
    DateTime startedAt;
    if (rawStartedAt is int) {
      startedAt = DateTime.fromMillisecondsSinceEpoch(rawStartedAt * 1000);
    } else if (rawStartedAt is String) {
      startedAt =
          DateTime.tryParse(rawStartedAt) ?? DateTime.now();
    } else {
      startedAt = DateTime.now();
    }

    return TrackingSession(
      id: id,
      startedAt: startedAt,
      activityName: data['activity_name'] as String?,
    );
  }

  @override
  Future<void> closeSession(String id) async {
    await _api.post(
      ApiPaths.sessionsStop,
      body: {'tracking_session_id': id},
    );
  }
}
