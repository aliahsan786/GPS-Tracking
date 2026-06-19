import '../core/errors/domain_error.dart';
import 'user.dart';

/// Response of `POST /api_auth_google.php`. The session token is what
/// we store and attach to every subsequent authenticated request (in
/// the JSON body, per the backend contract — not a Bearer header).
///
/// [fromJson] tolerates the current mock's minimal shape
/// (`{session_token: "..."}`) by falling back to a placeholder user.
class AuthResult {
  final String sessionToken;
  final User user;

  const AuthResult({required this.sessionToken, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final token = json['session_token'];
    if (token is! String || token.isEmpty) {
      // Defensive: a 2xx without a usable token (e.g. an error-shaped body
      // that slipped past the client). Surface a clear message instead of
      // a raw type-cast crash.
      throw const ServerError(
        message: 'Sign-in failed: no session token returned by the server.',
      );
    }
    final userJson = json['user'];
    return AuthResult(
      sessionToken: token,
      user: userJson is Map<String, dynamic>
          ? User.fromJson(userJson)
          : const User.placeholder(),
    );
  }
}
