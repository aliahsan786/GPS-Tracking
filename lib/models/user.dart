import 'package:equatable/equatable.dart';

/// Authenticated user, as returned by the Fanthrofit backend after it
/// verifies the Google ID token.
///
/// `id` and `email` are optional in [fromJson] because the current mock
/// backend only returns a `session_token` and no user block. When the
/// real backend ships with profile fields, those just populate these
/// slots — no further change required.
class User extends Equatable {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;

  const User({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
  });

  /// Placeholder used when the backend omits the user object. Lets us
  /// keep a non-null `User` everywhere instead of leaking nulls up to
  /// the UI.
  const User.placeholder()
      : id = 'unknown',
        email = 'unknown@fanthrofit.com',
        name = null,
        avatarUrl = null;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String? ?? 'unknown',
        email: json['email'] as String? ?? 'unknown@fanthrofit.com',
        name: json['name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );

  @override
  List<Object?> get props => [id, email, name, avatarUrl];
}
