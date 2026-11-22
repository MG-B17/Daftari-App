import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/errors/app_exception.dart';

/// Persists the local ledger's linked account ID in [FlutterSecureStorage],
/// isolated from the security PIN record. Signing out never clears this key.
class LedgerOwnerStorage {
  LedgerOwnerStorage(this._storage);

  final FlutterSecureStorage _storage;
  Future<void> _operationQueue = Future<void>.value();

  static const ownerKey = 'daftari.auth.ledger_owner.v1';

  Future<String?> readOwnerId() async {
    try {
      final value = await _storage.read(key: ownerKey);
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      throw const StorageException();
    }
  }

  /// Atomically claims the ledger owner ID if unlinked.
  ///
  /// Serializes concurrent callers so only the first owner is written. Once an
  /// owner is set, repeats for the same ID are no-ops and a different ID never
  /// replaces it. When [canClaim] is provided and returns `false` synchronously
  /// right before the first write, the ledger remains unlinked and `null` is
  /// returned.
  Future<String?> claimOwnerId(String userId, {bool Function()? canClaim}) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return Future.error(const ValidationException());

    final completer = Completer<String?>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        final existing = await readOwnerId();
        if (existing != null) {
          completer.complete(existing);
          return;
        }
        if (canClaim != null && !canClaim()) {
          completer.complete(null);
          return;
        }
        await _storage.write(key: ownerKey, value: trimmed);
        completer.complete(trimmed);
      } catch (error, stackTrace) {
        if (error is AppException) {
          completer.completeError(error, stackTrace);
        } else {
          completer.completeError(const StorageException(), stackTrace);
        }
      }
    });
    return completer.future;
  }
}
