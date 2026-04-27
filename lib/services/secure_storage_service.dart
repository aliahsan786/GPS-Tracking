import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around platform secure storage.
///
/// Only the Fanthrofit session token lives here right now — we treat the
/// Google ID token as transient (used once during sign-in, then discarded).
abstract class SecureStorageService {
  Future<void> writeSessionToken(String token);
  Future<String?> readSessionToken();
  Future<void> deleteSessionToken();
  Future<void> clear();
}

class SecureStorageServiceImpl implements SecureStorageService {
  static const _keySessionToken = 'fanthrofit_session_token';

  final FlutterSecureStorage _storage;

  SecureStorageServiceImpl({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // EncryptedSharedPreferences on Android so data survives
              // backup/restore correctly and is AES-encrypted at rest.
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  @override
  Future<void> writeSessionToken(String token) =>
      _storage.write(key: _keySessionToken, value: token);

  @override
  Future<String?> readSessionToken() => _storage.read(key: _keySessionToken);

  @override
  Future<void> deleteSessionToken() =>
      _storage.delete(key: _keySessionToken);

  @override
  Future<void> clear() => _storage.deleteAll();
}
