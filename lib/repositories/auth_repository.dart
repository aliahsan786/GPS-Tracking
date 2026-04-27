import '../core/constants/api_paths.dart';
import '../models/auth_result.dart';
import '../services/api_client.dart';

/// Boundary between the auth provider and the auth API.
///
/// Contract: providers get an [AuthResult] back or a `DomainError`
/// thrown. They never see Dio.
abstract class AuthRepository {
  /// Exchanges a Google ID token for a Fanthrofit session token.
  Future<AuthResult> exchangeGoogleToken(String googleIdToken);

  /// Local-only at the moment — the backend hasn't exposed a logout
  /// endpoint. AuthProvider clears the stored token regardless.
  Future<void> logout();
}

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _api;
  AuthRepositoryImpl(this._api);

  @override
  Future<AuthResult> exchangeGoogleToken(String googleIdToken) async {
    // skipAuth: the request carries the Google ID token as payload;
    // the backend hasn't issued our session_token yet.
    final data = await _api.post(
      ApiPaths.authGoogle,
      body: {'google_id_token': googleIdToken},
      skipAuth: true,
    );
    return AuthResult.fromJson(data);
  }

  @override
  Future<void> logout() async {
    // No-op until the backend exposes a logout route.
  }
}
