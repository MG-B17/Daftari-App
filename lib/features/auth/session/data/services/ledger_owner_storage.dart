import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../../core/errors/app_exception.dart';

/// Persists the local ledger's linked account ID in [FlutterSecureStorage],
/// isolated from the security PIN record, and coordinates with SQLite's durable
/// ledger owner binding when bound to a database instance. Signing out never
/// clears this key.
class LedgerOwnerStorage {
  LedgerOwnerStorage(
    FlutterSecureStorage storage, {
    Future<String?> Function()? readDurableOwnerId,
    Future<String> Function(String ownerUserId)? claimDurableOwnerId,
  }) : this._(storage, readDurableOwnerId, claimDurableOwnerId);

  LedgerOwnerStorage._(
    this._storage,
    this._readDurableOwnerId,
    this._claimDurableOwnerId,
  );

  final FlutterSecureStorage _storage;
  Future<String?> Function()? _readDurableOwnerId;
  Future<String> Function(String ownerUserId)? _claimDurableOwnerId;
  Future<void> _operationQueue = Future<void>.value();

  static const ownerKey = 'daftari.auth.ledger_owner.v1';

  /// Binds SQLite-backed durable owner callbacks so that even if a
  /// [FlutterSecureStorage] write fails or the process dies immediately after a
  /// SQLite restore commit, the restored rows remain durably bound to their
  /// owner across restarts and account switches.
  void bindDurableOwnerCallbacks({
    required Future<String?> Function() readDurableOwnerId,
    Future<String> Function(String ownerUserId)? claimDurableOwnerId,
  }) {
    _readDurableOwnerId ??= readDurableOwnerId;
    _claimDurableOwnerId ??= claimDurableOwnerId;
  }

  Future<String?> readOwnerId() async {
    String? secureOwner;
    Object? secureReadError;
    try {
      final value = await _storage.read(key: ownerKey);
      final trimmed = value?.trim();
      secureOwner = trimmed == null || trimmed.isEmpty ? null : trimmed;
    } catch (error) {
      secureReadError = error;
    }

    // Fast path: owner binding is write-once, so a persisted secure-storage
    // owner avoids touching SQLite (preventing lock contention or deadlocks
    // when called concurrently with an active Drift transaction).
    if (secureOwner != null) {
      return secureOwner;
    }

    String? durableOwner;
    final durableReader = _readDurableOwnerId;
    if (durableReader != null) {
      try {
        final rawDurable = await durableReader();
        final trimmedDurable = rawDurable?.trim();
        if (trimmedDurable != null && trimmedDurable.isNotEmpty) {
          durableOwner = trimmedDurable;
        }
      } catch (_) {
        // Fall through if SQLite is not readable.
      }
    }

    if (durableOwner != null) {
      if (secureReadError == null) {
        try {
          await _storage.write(key: ownerKey, value: durableOwner);
        } catch (_) {
          // Best-effort repair of secure storage from durable SQLite owner.
        }
      }
      return durableOwner;
    }

    if (secureReadError != null) {
      throw const StorageException();
    }
    return null;
  }

  /// Atomically claims the ledger owner ID if unlinked.
  ///
  /// Serializes concurrent callers so only the first owner is written. Once an
  /// owner is set (in either durable SQLite or secure storage), repeats for the
  /// same ID are no-ops and a different ID never replaces it. When [canClaim]
  /// is provided and returns `false` synchronously right before the first
  /// write, the ledger remains unlinked and `null` is returned.
  Future<String?> claimOwnerId(String userId, {bool Function()? canClaim}) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return Future.error(const ValidationException());

    final completer = Completer<String?>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        final rawSecure = await _storage.read(key: ownerKey);
        final trimmedSecure = rawSecure?.trim();
        final secureOwner = (trimmedSecure == null || trimmedSecure.isEmpty)
            ? null
            : trimmedSecure;

        if (secureOwner != null) {
          if (secureOwner == trimmed) {
            final claimDurable = _claimDurableOwnerId;
            if (claimDurable != null) {
              try {
                final winner = await claimDurable(trimmed);
                completer.complete(winner);
                return;
              } catch (_) {
                // Best-effort durable sync if database is closed or unavailable.
              }
            }
          }
          completer.complete(secureOwner);
          return;
        }

        String? durableOwner;
        final durableReader = _readDurableOwnerId;
        if (durableReader != null) {
          try {
            final rawDurable = await durableReader();
            final trimmedDurable = rawDurable?.trim();
            if (trimmedDurable != null && trimmedDurable.isNotEmpty) {
              durableOwner = trimmedDurable;
            }
          } catch (_) {
            // Fall through if SQLite is not readable.
          }
        }

        if (durableOwner != null && durableOwner != trimmed) {
          try {
            await _storage.write(key: ownerKey, value: durableOwner);
          } catch (_) {
            // Best-effort repair of secure storage from durable SQLite owner.
          }
          completer.complete(durableOwner);
          return;
        }
        if (durableOwner == null && canClaim != null && !canClaim()) {
          completer.complete(null);
          return;
        }
        await _storage.write(key: ownerKey, value: trimmed);
        final claimDurable = _claimDurableOwnerId;
        if (claimDurable != null) {
          try {
            final winner = await claimDurable(trimmed);
            if (winner != trimmed) {
              completer.complete(winner);
              return;
            }
          } catch (_) {
            // Best-effort durable sync if database is closed or unavailable.
          }
        }
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
