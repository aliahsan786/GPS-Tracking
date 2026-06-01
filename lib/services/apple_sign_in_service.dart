import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

abstract class AppleSignInService {
  /// Returns the Apple identity token on success, `null` if cancelled.
  Future<String?> signIn();

  static Future<bool> get isAvailable => SignInWithApple.isAvailable();
}

class AppleSignInFailed implements Exception {
  final String message;
  final Object? original;
  AppleSignInFailed(this.message, [this.original]);

  @override
  String toString() => 'AppleSignInFailed: $message';
}

class AppleSignInServiceImpl implements AppleSignInService {
  @override
  Future<String?> signIn() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw AppleSignInFailed('No identity token returned from Apple.');
      }
      return idToken;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      // error 1000 = capability not configured in Xcode / Apple Developer
      if (e.code == AuthorizationErrorCode.unknown) {
        throw AppleSignInFailed(
          'Apple Sign-In is not configured. Add the "Sign In with Apple" '
          'capability in Xcode and enable it in your Apple Developer account.',
          e,
        );
      }
      throw AppleSignInFailed(e.message, e);
    } catch (e, stack) {
      debugPrint('[apple_sign_in] failed: $e\n$stack');
      // Wrap any unexpected error so AuthProvider always catches AppleSignInFailed
      // and never lets an unhandled exception crash the app.
      if (e is AppleSignInFailed) rethrow;
      throw AppleSignInFailed(e.toString(), e);
    }
  }
}
