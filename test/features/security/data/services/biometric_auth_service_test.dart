import 'package:daftariapp/features/security/data/services/biometric_auth_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends Mock implements LocalAuthentication {}

void main() {
  late _MockAuth auth;
  late BiometricAuthService service;
  var reason = 'Localized biometric reason';

  setUp(() {
    auth = _MockAuth();
    service = BiometricAuthService(
      auth,
      biometricReason: () => reason,
      recoveryReason: () => 'Localized recovery',
    );
    when(() => auth.canCheckBiometrics).thenAnswer((_) async => true);
    when(() => auth.getAvailableBiometrics())
        .thenAnswer((_) async => [BiometricType.fingerprint]);
    when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
    when(
      () => auth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: any(named: 'biometricOnly'),
        persistAcrossBackgrounding: false,
      ),
    ).thenAnswer((_) async => true);
  });

  test(
    'biometric unlock forbids device PIN fallback and uses current locale',
    () async {
      reason = 'فتح القفل بالبصمة';
      expect(await service.authenticateWithBiometrics(), isTrue);
      verify(
        () => auth.authenticate(
          localizedReason: reason,
          biometricOnly: true,
          persistAcrossBackgrounding: false,
        ),
      ).called(1);
    },
  );

  test('recovery permits OS credentials without enrolled biometrics', () async {
    when(() => auth.canCheckBiometrics).thenAnswer((_) async => false);
    expect(await service.authenticateWithDeviceCredential(), isTrue);
    verify(
      () => auth.authenticate(
        localizedReason: 'Localized recovery',
        biometricOnly: false,
        persistAcrossBackgrounding: false,
      ),
    ).called(1);
  });

  test(
    'hardware alone without enrollment cannot show biometric unlock',
    () async {
      when(() => auth.getAvailableBiometrics()).thenAnswer((_) async => []);
      expect(await service.canAuthenticateWithBiometrics(), isFalse);
      expect(await service.authenticateWithBiometrics(), isFalse);
      verifyNever(
        () => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
          persistAcrossBackgrounding: false,
        ),
      );
    },
  );

  test('no device lock means no recovery challenge', () async {
    when(() => auth.isDeviceSupported()).thenAnswer((_) async => false);
    expect(await service.authenticateWithDeviceCredential(), isFalse);
    verifyNever(
      () => auth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: any(named: 'biometricOnly'),
        persistAcrossBackgrounding: false,
      ),
    );
  });

  test(
    'cancellation, OS lockout and platform failures return PIN fallback',
    () async {
      for (final error in [
        const LocalAuthException(code: LocalAuthExceptionCode.userCanceled),
        const LocalAuthException(code: LocalAuthExceptionCode.temporaryLockout),
        PlatformException(code: 'secret', message: 'private details'),
        Exception('private details'),
      ]) {
        when(
          () => auth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            biometricOnly: any(named: 'biometricOnly'),
            persistAcrossBackgrounding: false,
          ),
        ).thenThrow(error);
        expect(await service.authenticateWithBiometrics(), isFalse);
        expect(await service.authenticateWithDeviceCredential(), isFalse);
      }
    },
  );

  test('capability errors and rejected challenge fail closed', () async {
    when(() => auth.canCheckBiometrics).thenThrow(Exception('private details'));
    when(() => auth.isDeviceSupported())
        .thenThrow(Exception('private details'));
    expect(await service.canAuthenticateWithBiometrics(), isFalse);
    expect(await service.isDeviceLockSupported(), isFalse);
    expect(await service.authenticateWithBiometrics(), isFalse);
    expect(await service.authenticateWithDeviceCredential(), isFalse);
  });
}
