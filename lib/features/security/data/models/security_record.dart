import '../../../../core/errors/app_exception.dart';
import '../../domain/policies/pin_lockout_policy.dart';
import '../services/pin_hasher.dart';

final class SecurityRecord {
  factory SecurityRecord({
    PinHash? hash,
    PinLockoutState lockout = const PinLockoutState.clear(),
    bool biometricEnabled = false,
    int revision = 0,
  }) {
    if (revision < 0 ||
        (hash == null &&
            (biometricEnabled || lockout != const PinLockoutState.clear()))) {
      throw const StorageException();
    }
    return SecurityRecord._(hash, lockout, biometricEnabled, revision);
  }

  const SecurityRecord._(
    this.hash,
    this.lockout,
    this.biometricEnabled,
    this.revision,
  );

  factory SecurityRecord.fromJson(Map<String, dynamic> json) {
    try {
      if (json['schema'] is! int ||
          json['schema'] != 1 ||
          json['revision'] is! int ||
          !json.containsKey('credential') ||
          !json.containsKey('lockoutUntil') ||
          json['biometricEnabled'] is! bool ||
          json['failedAttempts'] is! int) {
        throw const StorageException();
      }
      final credential = json['credential'] as Map<String, dynamic>?;
      final deadline = json['lockoutUntil'] as int?;
      return SecurityRecord(
        hash: credential == null
            ? null
            : PinHash(
                salt: (credential['salt'] as List).cast<int>(),
                verifier: (credential['verifier'] as List).cast<int>(),
                version: credential['version'] as int,
                iterations: credential['iterations'] as int,
              ),
        lockout: PinLockoutState(
          failedAttempts: json['failedAttempts'] as int,
          lockoutUntil: deadline == null
              ? null
              : DateTime.fromMicrosecondsSinceEpoch(deadline, isUtc: true),
        ),
        biometricEnabled: json['biometricEnabled'] as bool,
        revision: json['revision'] as int,
      );
    } catch (_) {
      throw const StorageException();
    }
  }

  final PinHash? hash;
  final PinLockoutState lockout;
  final bool biometricEnabled;
  final int revision;

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'revision': revision,
    'credential': hash == null
        ? null
        : {
            'version': hash!.version,
            'iterations': hash!.iterations,
            'salt': hash!.salt,
            'verifier': hash!.verifier,
          },
    'failedAttempts': lockout.failedAttempts,
    'lockoutUntil': lockout.lockoutUntil?.microsecondsSinceEpoch,
    'biometricEnabled': biometricEnabled,
  };

  @override
  String toString() => 'SecurityRecord(redacted)';
}
