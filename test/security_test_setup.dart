import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/services/date_service.dart';
import 'package:daftariapp/features/security/domain/entities/pin_verify_result.dart';
import 'package:daftariapp/features/security/domain/entities/security_settings.dart';
import 'package:daftariapp/features/security/domain/policies/pin_lockout_policy.dart';
import 'package:daftariapp/features/security/domain/repositories/security_repository.dart';
import 'package:daftariapp/features/security/presentation/cubit/app_lock_cubit.dart';
import 'package:fpdart/fpdart.dart';

class SecurityTestClock implements DateService {
  DateTime time = DateTime.utc(2026, 11, 20);
  @override
  DateTime now() => time;
}

class TestSecurityRepository implements SecurityRepository {
  TestSecurityRepository({this.pin, this.biometricEnabled = false});
  String? pin;
  bool biometricEnabled;
  bool biometricAvailable = true;
  bool deviceAvailable = false;
  bool biometricSuccess = false;
  bool recoverySuccess = false;
  bool authorized = false;
  bool fail = false;
  int attempts = 0;
  int verificationCalls = 0;
  int osCalls = 0;
  DateTime? deadline;
  AutoLockTimeout timeout = AutoLockTimeout.immediate;
  Future<void>? verificationBarrier;

  Either<AppFailure, T> result<T>(T value) =>
      fail ? const Left(AppFailure(AppErrorCode.storage)) : Right(value);
  @override
  Future<Either<AppFailure, SecuritySettings>> getSettings() async => result(
    SecuritySettings(
      isPinEnabled: pin != null,
      isBiometricEnabled: biometricEnabled,
      autoLockTimeout: timeout,
    ),
  );
  @override
  Future<Either<AppFailure, PinLockoutState>> getLockoutState() async =>
      result(PinLockoutState(failedAttempts: attempts, lockoutUntil: deadline));
  @override
  Future<Either<AppFailure, void>> setupPin(String value) async {
    pin = value;
    return result(null);
  }

  @override
  Future<Either<AppFailure, PinVerifyResult>> verifyPin(String value) async {
    verificationCalls++;
    await verificationBarrier;
    if (pin == null) return result(const PinNotConfigured());
    if (value == pin) {
      attempts = 0;
      deadline = null;
      return result(const PinVerified());
    }
    attempts++;
    if (attempts == 5) {
      deadline = DateTime.utc(2026, 11, 20).add(const Duration(seconds: 30));
      return result(PinLockedOut(until: deadline!));
    }
    return result(PinIncorrect(remainingAttempts: 5 - attempts));
  }

  @override
  Future<Either<AppFailure, PinVerifyResult>> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final verified = await verifyPin(currentPin);
    if (verified.toNullable() is PinVerified) pin = newPin;
    return verified;
  }

  @override
  Future<Either<AppFailure, PinVerifyResult>> disablePin(String value) async {
    final verified = await verifyPin(value);
    if (verified.toNullable() is PinVerified) {
      pin = null;
      biometricEnabled = false;
    }
    return verified;
  }

  @override
  Future<Either<AppFailure, bool>> canAuthenticateWithBiometrics() async =>
      result(biometricAvailable);
  @override
  Future<Either<AppFailure, bool>> isDeviceLockSupported() async =>
      result(deviceAvailable);
  @override
  Future<Either<AppFailure, bool>> authenticateWithBiometrics() async {
    osCalls++;
    return result(biometricSuccess);
  }

  @override
  Future<Either<AppFailure, bool>> authorizePinReset() async {
    osCalls++;
    authorized = recoverySuccess;
    return result(authorized);
  }

  @override
  void cancelPinReset() => authorized = false;
  @override
  Future<Either<AppFailure, bool>> resetPinWithDeviceCredential(
    String value,
  ) async {
    if (!authorized) return result(false);
    authorized = false;
    pin = value;
    attempts = 0;
    deadline = null;
    biometricEnabled = false;
    return result(true);
  }

  @override
  Future<Either<AppFailure, bool>> setBiometricEnabled(bool enabled) async {
    biometricEnabled = enabled;
    return result(true);
  }

  @override
  Future<Either<AppFailure, void>> setAutoLockTimeout(
    AutoLockTimeout value,
  ) async {
    timeout = value;
    return result(null);
  }
}

Future<AppLockCubit> testAppLock({TestSecurityRepository? repository}) async {
  final cubit = AppLockCubit(
    repository ?? TestSecurityRepository(),
    SecurityTestClock(),
  );
  await cubit.initialize();
  return cubit;
}
