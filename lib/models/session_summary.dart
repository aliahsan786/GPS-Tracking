import 'package:equatable/equatable.dart';

/// Last-completed-activity summary shown on the Idle tracking state.
class SessionSummary extends Equatable {
  final String name;
  final double distanceMeters;
  final Duration duration;

  const SessionSummary({
    required this.name,
    required this.distanceMeters,
    required this.duration,
  });

  @override
  List<Object?> get props => [name, distanceMeters, duration];
}
