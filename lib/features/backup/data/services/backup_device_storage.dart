import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';

/// Immutable installation identity (`deviceId`) paired with its local-only
/// high-entropy authentication credential (`deviceSecret`).
final class BackupDeviceIdentity extends Equatable {
  const BackupDeviceIdentity({
    required this.deviceId,
    required this.deviceSecret,
  });

  final String deviceId;
  final String deviceSecret;

  @override
  bool get stringify => false;

  @override
  String toString() =>
      'BackupDeviceIdentity(deviceId: $deviceId, deviceSecret: <redacted>)';

  @override
  List<Object> get props => [deviceId, deviceSecret];
}

/// Persists this installation's canonical backup identity and secret across
/// foreground and background worker instances.
///
/// Uses SQLite (`backup_device_identities` with `INSERT OR IGNORE` on a
/// singleton row) as the cross-instance / cross-process arbiter for the
/// canonical `deviceId`, and stores each candidate's 256-bit secret under a
/// per-`deviceId` key in [FlutterSecureStorage] before claiming the SQLite row.
/// Competing first-use instances therefore never overwrite each other's secrets
/// and always converge on one winning identity.
class BackupDeviceStorage {
  BackupDeviceStorage(
    this._storage,
    this._backupDao, {
    String Function()? generateDeviceId,
    String Function()? generateDeviceSecret,
  }) : _generateDeviceId = generateDeviceId ?? _defaultGenerateDeviceId,
       _generateDeviceSecret =
           generateDeviceSecret ?? _defaultGenerateDeviceSecret;

  static const _secretKeyPrefix = 'daftari.backup.device_secret.v1.';
  static const minSecretLength = 32;

  static const _uuid = Uuid();
  static String _defaultGenerateDeviceId() => _uuid.v4();

  static String _defaultGenerateDeviceSecret() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static String secretKeyFor(String deviceId) => '$_secretKeyPrefix$deviceId';

  final FlutterSecureStorage _storage;
  final BackupDao _backupDao;
  final String Function() _generateDeviceId;
  final String Function() _generateDeviceSecret;

  Future<String?> readDeviceId() => _backupDao.readDeviceId();

  Future<BackupDeviceIdentity?> readIdentity() async {
    final deviceId = await _backupDao.readDeviceId();
    if (deviceId == null) return null;
    final secret = await _readSecret(deviceId);
    if (secret == null) {
      throw const StorageException();
    }
    return BackupDeviceIdentity(deviceId: deviceId, deviceSecret: secret);
  }

  Future<String> getOrCreateDeviceId() async =>
      (await getOrCreateIdentity()).deviceId;

  /// Returns the canonical persisted installation identity, converging
  /// atomically on one `(deviceId, deviceSecret)` pair across independent
  /// foreground and background instances.
  Future<BackupDeviceIdentity> getOrCreateIdentity() async {
    final existingId = await _backupDao.readDeviceId();
    if (existingId != null) {
      final secret = await _readSecret(existingId);
      if (secret == null) {
        throw const StorageException();
      }
      return BackupDeviceIdentity(deviceId: existingId, deviceSecret: secret);
    }

    final candidateId = _generateDeviceId().trim();
    final candidateSecret = _generateDeviceSecret().trim();
    if (candidateId.isEmpty || candidateSecret.length < minSecretLength) {
      throw const ValidationException();
    }

    // Persist the candidate secret under its own unique key BEFORE claiming the
    // singleton SQLite row so any competing instance that loses the SQLite
    // race immediately finds the winner's secret already stored.
    await _writeSecret(candidateId, candidateSecret);

    final String winningId;
    try {
      winningId = await _backupDao.claimOrReadDeviceId(candidateId);
    } catch (_) {
      await _deleteSecretBestEffort(candidateId);
      rethrow;
    }

    if (winningId == candidateId) {
      return BackupDeviceIdentity(
        deviceId: winningId,
        deviceSecret: candidateSecret,
      );
    }

    // Another instance won first-claim; clean up our unused candidate secret
    // and return the winning identity.
    await _deleteSecretBestEffort(candidateId);
    final winningSecret = await _readSecret(winningId);
    if (winningSecret == null) {
      throw const StorageException();
    }
    return BackupDeviceIdentity(
      deviceId: winningId,
      deviceSecret: winningSecret,
    );
  }

  Future<String?> _readSecret(String deviceId) async {
    try {
      final value = await _storage.read(key: secretKeyFor(deviceId));
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.length < minSecretLength) return null;
      return trimmed;
    } catch (_) {
      throw const StorageException();
    }
  }

  Future<void> _writeSecret(String deviceId, String secret) async {
    try {
      await _storage.write(key: secretKeyFor(deviceId), value: secret);
    } catch (_) {
      throw const StorageException();
    }
  }

  Future<void> _deleteSecretBestEffort(String deviceId) async {
    try {
      await _storage.delete(key: secretKeyFor(deviceId));
    } catch (_) {
      // Best-effort cleanup of an unreferenced candidate key.
    }
  }
}
