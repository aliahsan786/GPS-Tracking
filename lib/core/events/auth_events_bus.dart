import 'dart:async';

/// One-way event bus for auth-related side effects.
///
/// [ApiClient] emits [SessionExpiredEvent] from its 401 interceptor.
/// [AuthProvider] subscribes and flips its state + triggers the
/// `SessionExpired` tracking UI state.
///
/// Using a bus (instead of a direct ApiClient -> AuthProvider call) keeps
/// the service layer free of provider dependencies — services remain
/// trivially unit-testable.
class AuthEventsBus {
  final StreamController<AuthEvent> _controller =
      StreamController<AuthEvent>.broadcast();

  Stream<AuthEvent> get stream => _controller.stream;

  void emit(AuthEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  Future<void> dispose() => _controller.close();
}

sealed class AuthEvent {
  const AuthEvent();
}

/// Fired when any authenticated request receives HTTP 401.
class SessionExpiredEvent extends AuthEvent {
  final DateTime at;
  SessionExpiredEvent() : at = DateTime.now();
}
