import '../core/constants/api_paths.dart';
import '../models/auth_result.dart';
import '../services/api_client.dart';

abstract class AuthRepository {
  Future<AuthResult> exchangeGoogleToken(String googleIdToken);
  Future<AuthResult> exchangeAppleToken(String appleIdToken);
  Future<void> logout();
}

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _api;
  AuthRepositoryImpl(this._api);

  @override
  Future<AuthResult> exchangeGoogleToken(String googleIdToken) async {
    final data = await _api.post(
      ApiPaths.authGoogle,
      body: {'google_id_token': googleIdToken},
      skipAuth: true,
    );
    return AuthResult.fromJson(data);
  }

  @override
  Future<AuthResult> exchangeAppleToken(String appleIdToken) async {
    final data = await _api.post(
      ApiPaths.authApple,
      body: {'apple_id_token': appleIdToken},
      skipAuth: true,
    );
    return AuthResult.fromJson(data);
  }

  @override
  Future<void> logout() async {}
}
