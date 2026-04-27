import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around the native Google Sign-In SDK.
///
/// We only need the Google-issued ID token. The backend verifies it and
/// returns our Fanthrofit session token, which is what we persist.
///
/// Platform setup required:
///   - Android: the app's SHA-1 must be registered on an Android OAuth
///     2.0 client in Google Cloud Console, matching the package name
///     (`com.example.gps_tracking` until renamed).
///   - iOS: `REVERSED_CLIENT_ID` in Info.plist (URL types).
///   - For an `idToken` to come back you usually also need a *Web*
///     OAuth client — pass its ID as `serverClientId` below.
abstract class GoogleSignInService {
  /// Returns the Google ID token on success, `null` if the user
  /// cancelled the picker. Throws [GoogleSignInFailed] on SDK errors
  /// so the caller can show the actual reason during dev.
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

  GoogleSignInServiceImpl({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile', 'openid'],
              // Web OAuth 2.0 Client ID from google-services.json
              // (the entry with `client_type: 3`). Required for Android
              // to return an idToken.
              serverClientId:
                  '1021928700381-0fss1sdo7870o8fh9m3sh4iqpin5u1ug.apps.googleusercontent.com',
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
