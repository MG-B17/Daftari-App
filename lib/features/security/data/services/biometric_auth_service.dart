import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  BiometricAuthService(
    this._authentication, {
    required this.biometricReason,
    required this.recoveryReason,
  });

  final LocalAuthentication _authentication;
  final String Function() biometricReason;
  final String Function() recoveryReason;

  Future<bool> canAuthenticateWithBiometrics() async {
    try {
      return await _authentication.canCheckBiometrics &&
          (await _authentication.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isDeviceLockSupported() async {
    try {
      return await _authentication.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      if (!await canAuthenticateWithBiometrics()) return false;
      return await _authentication.authenticate(
        localizedReason: biometricReason(),
        biometricOnly: true,
        persistAcrossBackgrounding: false,
      );
    } catch (_) {
      // Cancellation, hardware errors and OS lockouts all fall back to app PIN.
      return false;
    }
  }

  Future<bool> authenticateWithDeviceCredential() async {
    try {
      if (!await isDeviceLockSupported()) return false;
      // local_auth permits OS biometrics OR PIN/pattern/password in this mode.
      return await _authentication.authenticate(
        localizedReason: recoveryReason(),
        biometricOnly: false,
        persistAcrossBackgrounding: false,
      );
    } catch (_) {
      return false;
    }
  }
}
