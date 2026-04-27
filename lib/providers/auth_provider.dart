import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/domain_error.dart';
import '../core/events/auth_events_bus.dart';
import '../models/auth_status.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../services/google_sign_in_service.dart';
import '../services/secure_storage_service.dart';

/// Owns the auth lifecycle: bootstrap, sign-in, logout, and reacting to
/// backend 401s via [AuthEventsBus].
class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;
  final GoogleSignInService _google;
  final SecureStorageService _storage;
  final AuthEventsBus _bus;
  late final StreamSubscription<AuthEvent> _busSub;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _errorMessage;

  AuthProvider({
    required AuthRepository repo,
    required GoogleSignInService google,
    required SecureStorageService storage,
    required AuthEventsBus bus,
  })  : _repo = repo,
        _google = google,
        _storage = storage,
        _bus = bus {
    _busSub = _bus.stream.listen(_onBusEvent);
    _bootstrap();
  }

  AuthStatus get status => _status;
  User? get currentUser => _user;
  String? get errorMessage => _errorMessage;
  bool get isSigningIn => _status == AuthStatus.signingIn;
  bool get isExpired => _status == AuthStatus.expired;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> _bootstrap() async {
    try {
      final token = await _storage.readSessionToken();
      _status = (token != null && token.isNotEmpty)
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    if (_status == AuthStatus.signingIn) return;

    _errorMessage = null;
    _status = AuthStatus.signingIn;
    notifyListeners();

    try {
      final idToken = await _google.signIn();
      if (idToken == null) {
        // User cancelled the Google chooser.
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      final result = await _repo.exchangeGoogleToken(idToken);
      await _storage.writeSessionToken(result.sessionToken);
      _user = result.user;
      _status = AuthStatus.authenticated;
    } on DomainError catch (e, stack) {
      _errorMessage = _devMessage(_messageFor(e), e, stack);
      _status = AuthStatus.unauthenticated;
    } on GoogleSignInFailed catch (e, stack) {
      _errorMessage = _devMessage(
        'Google sign-in failed. Check OAuth config.',
        e,
        stack,
      );
      _status = AuthStatus.unauthenticated;
    } catch (e, stack) {
      _errorMessage = _devMessage(
        'Please try again or check your connection',
        e,
        stack,
      );
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Debug-only escape hatch so the Tracking screens are reachable
  /// without a working Google OAuth config. Writes a fake session
  /// token to secure storage and flips status to authenticated.
  /// Gated by [kDebugMode] at the call site.
  Future<void> devBypass() async {
    await _storage.writeSessionToken('sess_test_123');
    _user = const User.placeholder();
    _errorMessage = null;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    unawaited(_repo.logout());
    unawaited(_google.signOut());
    await _storage.deleteSessionToken();

    _user = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _onBusEvent(AuthEvent event) {
    if (event is SessionExpiredEvent) {
      _handleExpired();
    }
  }

  Future<void> _handleExpired() async {
    await _storage.deleteSessionToken();
    _status = AuthStatus.expired;
    notifyListeners();
  }

  /// Always logs the raw exception to the debug console, and in debug
  /// builds surfaces it in the UI too so we can see real error
  /// messages during development. Release builds show only the polite
  /// copy.
  String _devMessage(String polite, Object error, StackTrace stack) {
    debugPrint('[auth] $polite\n$error\n$stack');
    if (kDebugMode) return '$polite\n($error)';
    return polite;
  }

  String _messageFor(DomainError e) {
    switch (e) {
      case NetworkError():
        return 'No internet. Please check your connection.';
      case SessionExpiredError():
        return 'Please sign in again.';
      case ValidationError():
        return e.message;
      case ServerError():
      case UnknownError():
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  void dispose() {
    _busSub.cancel();
    super.dispose();
  }
}
