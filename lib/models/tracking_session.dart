import 'package:equatable/equatable.dart';

/// An active tracking session, as known locally.
///
/// `id` is assigned by the backend on `POST /tracking/sessions`.
/// Distance and duration are best-effort local values — the backend
/// remains the authoritative source (it re-computes from points it
/// receives).
class TrackingSession extends Equatable {
  final String id;
  final DateTime startedAt;
  final String? activityName;
  final double distanceMeters;
  final Duration duration;

  const TrackingSession({
    required this.id,
    required this.startedAt,
    this.activityName,
    this.distanceMeters = 0,
    this.duration = Duration.zero,
  });

  TrackingSession copyWith({
    String? activityName,
    double? distanceMeters,
    Duration? duration,
  }) {
    return TrackingSession(
      id: id,
      startedAt: startedAt,
      activityName: activityName ?? this.activityName,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      duration: duration ?? this.duration,
    );
  }

  @override
  List<Object?> get props => [id, startedAt, activityName, distanceMeters, duration];
}
