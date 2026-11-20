import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/pin_verify_result.dart';
import '../entities/security_settings.dart';
import '../policies/pin_lockout_policy.dart';

abstract interface class SecurityRepository {
  Future<Either<AppFailure, SecuritySettings>> getSettings();

  Future<Either<AppFailure, PinLockoutState>> getLockoutState();

  Future<Either<AppFailure, void>> setupPin(String pin);

  Future<Either<AppFailure, PinVerifyResult>> verifyPin(String pin);

  Future<Either<AppFailure, PinVerifyResult>> changePin({
    required String currentPin,
    required String newPin,
  });

  Future<Either<AppFailure, PinVerifyResult>> disablePin(String pin);

  Future<Either<AppFailure, bool>> canAuthenticateWithBiometrics();

  Future<Either<AppFailure, bool>> isDeviceLockSupported();

  Future<Either<AppFailure, bool>> authenticateWithBiometrics();

  Future<Either<AppFailure, bool>> authorizePinReset();

  void cancelPinReset();

  Future<Either<AppFailure, bool>> resetPinWithDeviceCredential(String newPin);

  Future<Either<AppFailure, bool>> setBiometricEnabled(bool enabled);

  Future<Either<AppFailure, void>> setAutoLockTimeout(AutoLockTimeout timeout);
}
