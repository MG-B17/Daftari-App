import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../../core/errors/app_exception.dart';

/// Snapshot of the currently persisted Supabase session in
/// [SecureSupabaseLocalStorage].
final class PersistedSessionSnapshot extends Equatable {
  const PersistedSessionSnapshot({
    required this.userId,
    required this.isEmailVerified,
  });

  final String? userId;
  final bool isEmailVerified;

  @override
  List<Object?> get props => [userId, isEmailVerified];
}

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

  /// Reads the currently persisted session identity, or `null` when no
  /// persisted session is present.
  Future<PersistedSessionSnapshot?> readSessionSnapshot() async {
    try {
      final raw = await _storage.read(key: sessionKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final parsed = _parseSessionUser(raw);
      return PersistedSessionSnapshot(
        userId: parsed.userId,
        isEmailVerified: parsed.isEmailVerified,
      );
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

  static ({String? userId, bool isEmailVerified}) _parseSessionUser(
    String? raw,
  ) {
    if (raw == null || raw.trim().isEmpty) {
      return (userId: null, isEmailVerified: false);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return (userId: null, isEmailVerified: true);
      }
      final userField = decoded['user'];
      final userMap = userField is Map<String, dynamic> ? userField : null;
      final rawId = userMap?['id'] ?? decoded['user_id'];
      final userId = rawId is String && rawId.trim().isNotEmpty
          ? rawId.trim()
          : null;

      var isEmailVerified = true;
      if (userMap != null) {
        if (userMap.containsKey('email_confirmed_at')) {
          final confirmedAt = userMap['email_confirmed_at'];
          isEmailVerified =
              confirmedAt is String && confirmedAt.trim().isNotEmpty;
        } else if (userMap.containsKey('email_verified')) {
          isEmailVerified = userMap['email_verified'] == true;
        }
      }
      return (userId: userId, isEmailVerified: isEmailVerified);
    } catch (_) {
      return (userId: null, isEmailVerified: true);
    }
  }
}
