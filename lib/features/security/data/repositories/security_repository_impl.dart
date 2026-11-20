import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/services/date_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../domain/entities/pin_verify_result.dart';
import '../../domain/entities/security_settings.dart';
import '../../domain/policies/pin_lockout_policy.dart';
import '../../domain/repositories/security_repository.dart';
import '../models/security_record.dart';
import '../services/biometric_auth_service.dart';
import '../services/pin_hasher.dart';
import '../services/secure_storage_service.dart';

class SecurityRepositoryImpl implements SecurityRepository {
  SecurityRepositoryImpl(
    this._secureStorage,
    this._biometrics,
    this._preferences,
    this._dateService,
    this._errorHandler, {
    this.hashPin = PinHasher.hash,
    this.verifyHash = PinHasher.verify,
  });

  final SecureStorageService _secureStorage;
  final BiometricAuthService _biometrics;
  final LocalStorageService _preferences;
  final DateService _dateService;
  final ErrorHandler _errorHandler;
  final Future<PinHash> Function(String) hashPin;
  final Future<bool> Function(String, PinHash) verifyHash;
  Future<void> _pending = Future.value();
  bool _storageFailed = false;
  int _recoveryGeneration = 0;
  int? _recoveryRevision;
  DateTime? _recoveryExpiry;

  // All reads, writes and OS prompts share the singleton's queue. No stale
  // verification may authorize a credential replaced by another operation.
  Future<Either<AppFailure, T>> _run<T>(Future<T> Function() operation) {
    final result = _pending.then<Either<AppFailure, T>>((_) async {
      try {
        if (_storageFailed) throw const StorageException();
        return Right(await operation());
      } catch (error) {
        // Never forward raw exceptions or stack traces to logging/Crashlytics.
        final safe = error is AppException ? error : const StorageException();
        return Left(await _errorHandler.handle(safe));
      }
    });
    _pending = result.then<void>((_) {});
    return result;
  }

  Future<SecurityRecord> _read() async {
    final record = await _secureStorage.read();
    if (record == null) {
      if (_preferences.securityInitialized ||
          _preferences.securityRevision != 0) {
        throw const StorageException();
      }
      return SecurityRecord();
    }
    if (record.revision != _preferences.securityRevision) {
      throw const StorageException();
    }
    if (!_preferences.securityInitialized) {
      await _preferences.markSecurityInitialized();
    }
    return record;
  }

  Future<void> _write(SecurityRecord record) async {
    try {
      // Set before the first secure write: interrupted setup fails closed.
      if (!_preferences.securityInitialized) {
        await _preferences.markSecurityInitialized();
      }
      // Android secure-storage uses apply(), not a synchronous disk commit.
      // Commit a non-secret revision FIRST via SharedPreferences (commit()).
      // If an abrupt kill drops the encrypted write, restart sees a mismatch
      // and stays closed rather than using an older credential/attempt ledger.
      final revision = _preferences.securityRevision + 1;
      await _preferences.setSecurityRevision(revision);
      await _secureStorage.write(
        SecurityRecord(
          hash: record.hash,
          lockout: record.lockout,
          biometricEnabled: record.biometricEnabled,
          revision: revision,
        ),
      );
    } catch (_) {
      // An unacknowledged write has unknown durability. Require restart rather
      // than retrying against potentially stale attempt or credential state.
      _storageFailed = true;
      throw const StorageException();
    }
  }

  void _validate(String pin) {
    if (!PinLockoutPolicy.isValidPin(pin)) throw const ValidationException();
  }

  @override
  Future<Either<AppFailure, SecuritySettings>> getSettings() => _run(() async {
    final record = await _read();
    return SecuritySettings(
      isPinEnabled: record.hash != null,
      isBiometricEnabled: record.biometricEnabled,
      autoLockTimeout: AutoLockTimeout.values.byName(
        _preferences.securityAutoLockTimeout,
      ),
    );
  });

  @override
  Future<Either<AppFailure, PinLockoutState>> getLockoutState() =>
      _run(() async {
        final record = await _read();
        final state = PinLockoutPolicy.normalize(
          record.lockout,
          _dateService.now(),
        );
        if (state != record.lockout) {
          await _write(
            SecurityRecord(
              hash: record.hash,
              lockout: state,
              biometricEnabled: record.biometricEnabled,
            ),
          );
        }
        return state;
      });

  @override
  Future<Either<AppFailure, void>> setupPin(String pin) => _run(() async {
    _validate(pin);
    if ((await _read()).hash != null) throw const AuthException();
    await _write(SecurityRecord(hash: await hashPin(pin)));
  });

  Future<PinVerifyResult> _verify(
    String pin, {
    String? replacement,
    bool disable = false,
  }) async {
    if (replacement != null) _validate(replacement);
    final record = await _read();
    if (PinLockoutPolicy.isLocked(record.lockout, _dateService.now())) {
      return PinLockedOut(until: record.lockout.lockoutUntil!);
    }
    if (!PinLockoutPolicy.isValidPin(pin)) return const PinInvalid();
    if (record.hash == null) return const PinNotConfigured();

    // Reserve the attempt durably BEFORE hashing. Killing the process mid-hash
    // must not allow unlimited guesses. A successful PIN clears the reservation.
    final failed = PinLockoutPolicy.recordFailure(
      record.lockout,
      _dateService.now(),
    );
    await _write(
      SecurityRecord(
        hash: record.hash,
        lockout: failed,
        biometricEnabled: record.biometricEnabled,
      ),
    );
    if (!await verifyHash(pin, record.hash!)) {
      if (failed.lockoutUntil != null) {
        return PinLockedOut(until: failed.lockoutUntil!);
      }
      return PinIncorrect(
        remainingAttempts:
            PinLockoutPolicy.maxFailedAttempts - failed.failedAttempts,
      );
    }
    await _write(
      SecurityRecord(
        hash: disable
            ? null
            : replacement == null
            ? record.hash
            : await hashPin(replacement),
        biometricEnabled: !disable && record.biometricEnabled,
      ),
    );
    return const PinVerified();
  }

  @override
  Future<Either<AppFailure, PinVerifyResult>> verifyPin(String pin) =>
      _run(() => _verify(pin));

  @override
  Future<Either<AppFailure, PinVerifyResult>> changePin({
    required String currentPin,
    required String newPin,
  }) => _run(() => _verify(currentPin, replacement: newPin));

  @override
  Future<Either<AppFailure, PinVerifyResult>> disablePin(String pin) =>
      _run(() => _verify(pin, disable: true));

  @override
  Future<Either<AppFailure, bool>> canAuthenticateWithBiometrics() =>
      _run(_biometrics.canAuthenticateWithBiometrics);

  @override
  Future<Either<AppFailure, bool>> isDeviceLockSupported() =>
      _run(_biometrics.isDeviceLockSupported);

  @override
  Future<Either<AppFailure, bool>> authenticateWithBiometrics() =>
      _run(() async {
        final record = await _read();
        if (record.hash == null ||
            !record.biometricEnabled ||
            PinLockoutPolicy.isLocked(record.lockout, _dateService.now())) {
          return false;
        }
        if (!await _biometrics.authenticateWithBiometrics()) return false;
        await _write(SecurityRecord(hash: record.hash, biometricEnabled: true));
        return true;
      });

  @override
  void cancelPinReset() {
    _recoveryGeneration++;
    _recoveryRevision = null;
    _recoveryExpiry = null;
  }

  @override
  Future<Either<AppFailure, bool>> authorizePinReset() => _run(() async {
    cancelPinReset();
    final generation = _recoveryGeneration;
    final record = await _read();
    if (record.hash == null ||
        !await _biometrics.authenticateWithDeviceCredential() ||
        generation != _recoveryGeneration) {
      return false;
    }
    _recoveryRevision = record.revision;
    _recoveryExpiry = _dateService.now().add(const Duration(minutes: 2));
    return true;
  });

  @override
  Future<Either<AppFailure, bool>> resetPinWithDeviceCredential(
    String newPin,
  ) => _run(() async {
    _validate(newPin);
    final record = await _read();
    if (record.hash == null) return false;
    final authorized =
        _recoveryRevision == record.revision &&
        _recoveryExpiry != null &&
        _dateService.now().isBefore(_recoveryExpiry!);
    cancelPinReset();
    if (!authorized && !await _biometrics.authenticateWithDeviceCredential()) {
      return false;
    }
    await _write(SecurityRecord(hash: await hashPin(newPin)));
    return true;
  });

  @override
  Future<Either<AppFailure, bool>> setBiometricEnabled(bool enabled) =>
      _run(() async {
        final record = await _read();
        if (record.hash == null) return false;
        if (enabled &&
            (PinLockoutPolicy.isLocked(record.lockout, _dateService.now()) ||
                !await _biometrics.authenticateWithBiometrics())) {
          return false;
        }
        await _write(
          SecurityRecord(
            hash: record.hash,
            lockout: record.lockout,
            biometricEnabled: enabled,
          ),
        );
        return true;
      });

  @override
  Future<Either<AppFailure, void>> setAutoLockTimeout(
    AutoLockTimeout timeout,
  ) => _run(() => _preferences.setSecurityAutoLockTimeout(timeout.name));
}
