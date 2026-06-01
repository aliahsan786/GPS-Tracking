import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_sign_in/google_sign_in.dart';

abstract class GoogleSignInService {
  Future<String?> signIn();
  Future<void> signOut();
}

class GoogleSignInFailed implements Exception {
  final String message;
  final Object? original;
  GoogleSignInFailed(this.message, [this.original]);

  @override
  String toString() => 'GoogleSignInFailed: $message';
}

class GoogleSignInServiceImpl implements GoogleSignInService {
  final GoogleSignIn _googleSignIn;

  // Web client ID (client_type: 3) from google-services.json — needed on
  // both platforms to get an idToken back from the server OAuth flow.
  static const _webClientId =
      '1021928700381-0fss1sdo7870o8fh9m3sh4iqpin5u1ug.apps.googleusercontent.com';

  GoogleSignInServiceImpl({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile', 'openid'],
              serverClientId: _webClientId,
            );

  @override
  Future<String?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null; // user cancelled

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw GoogleSignInFailed(
          'Signed in, but no idToken returned. Configure a Web OAuth '
          'client ID and pass it as `serverClientId` in '
          'GoogleSignInServiceImpl.',
        );
      }
      return idToken;
    } on GoogleSignInFailed {
      rethrow;
    } catch (e, stack) {
      debugPrint('[google_sign_in] failed: $e\n$stack');
      throw GoogleSignInFailed(e.toString(), e);
    }
  }

  @override
  Future<void> signOut() => _googleSignIn.signOut();
}
