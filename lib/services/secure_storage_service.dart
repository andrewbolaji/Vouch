import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around flutter_secure_storage.
///
/// On rooted/jailbroken devices, flutter_secure_storage uses
/// reduced security but still functions. Documented in
/// DECISIONS.md. Falls back gracefully on failure (returns
/// null, logs the error, does not crash).
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'auth_refresh_token';

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } on Exception catch (e) {
      debugPrint('SecureStorage: failed to save token: $e');
    }
  }

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } on Exception catch (e) {
      debugPrint('SecureStorage: failed to read token: $e');
      return null;
    }
  }

  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
    } on Exception catch (e) {
      debugPrint('SecureStorage: failed to save refresh token: $e');
    }
  }

  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } on Exception catch (e) {
      debugPrint('SecureStorage: failed to read refresh token: $e');
      return null;
    }
  }

  Future<void> clearAll() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _refreshTokenKey);
    } on Exception catch (e) {
      debugPrint('SecureStorage: failed to clear: $e');
    }
  }
}
