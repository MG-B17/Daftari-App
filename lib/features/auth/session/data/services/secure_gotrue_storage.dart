import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../../core/errors/app_exception.dart';

/// PKCE verifier storage backed by [FlutterSecureStorage], isolated from the
/// security PIN record and ledger-owner key.
class SecureGotrueStorage extends sb.GotrueAsyncStorage {
  SecureGotrueStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const keyPrefix = 'daftari.auth.gotrue.';

  String _scopedKey(String key) => '$keyPrefix$key';

  @override
  Future<String?> getItem({required String key}) async {
    try {
      return await _storage.read(key: _scopedKey(key));
    } catch (_) {
      throw const StorageException();
    }
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    try {
      await _storage.write(key: _scopedKey(key), value: value);
    } catch (_) {
      throw const StorageException();
    }
  }

  @override
  Future<void> removeItem({required String key}) async {
    try {
      await _storage.delete(key: _scopedKey(key));
    } catch (_) {
      throw const StorageException();
    }
  }
}

/// Persisted Supabase session storage backed by [FlutterSecureStorage].
class SecureSupabaseLocalStorage extends sb.LocalStorage {
  const SecureSupabaseLocalStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const sessionKey = 'daftari.auth.session.v1';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    try {
      final token = await _storage.read(key: sessionKey);
      return token != null && token.isNotEmpty;
    } catch (_) {
      throw const StorageException();
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _storage.read(key: sessionKey);
    } catch (_) {
      throw const StorageException();
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: sessionKey, value: persistSessionString);
    } catch (_) {
      throw const StorageException();
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: sessionKey);
    } catch (_) {
      throw const StorageException();
    }
  }
}
