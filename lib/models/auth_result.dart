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
    final userJson = json['user'];
    return AuthResult(
      sessionToken: json['session_token'] as String,
      user: userJson is Map<String, dynamic>
          ? User.fromJson(userJson)
          : const User.placeholder(),
    );
  }
}
