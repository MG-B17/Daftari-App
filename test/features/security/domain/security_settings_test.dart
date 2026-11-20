import 'package:daftariapp/features/security/domain/entities/pin_flow_mode.dart';
import 'package:daftariapp/features/security/domain/entities/pin_verify_result.dart';
import 'package:daftariapp/features/security/domain/entities/security_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings default to disabled security and immediate auto-lock', () {
    const settings = SecuritySettings();
    expect(settings.isPinEnabled, isFalse);
    expect(settings.isBiometricEnabled, isFalse);
    expect(settings.autoLockTimeout, AutoLockTimeout.immediate);
  });

  test(
    'biometrics require a PIN, including when disabling an existing PIN',
    () {
      expect(
        const SecuritySettings(isBiometricEnabled: true).isBiometricEnabled,
        isFalse,
      );
      const enabled = SecuritySettings(
        isPinEnabled: true,
        isBiometricEnabled: true,
        autoLockTimeout: AutoLockTimeout.fiveMinutes,
      );
      final disabled = enabled.copyWith(isPinEnabled: false);
      expect(disabled.isBiometricEnabled, isFalse);
      expect(disabled.autoLockTimeout, AutoLockTimeout.fiveMinutes);
      expect(disabled.copyWith(isPinEnabled: true).isBiometricEnabled, isFalse);
      expect(enabled.isBiometricEnabled, isTrue);
    },
  );

  test('copyWith preserves values and settings have value equality', () {
    const settings = SecuritySettings(isPinEnabled: true);
    expect(settings.copyWith(), settings);
    expect(settings.copyWith().hashCode, settings.hashCode);
    expect(settings.copyWith(isBiometricEnabled: true), isNot(settings));
    expect(
      settings.copyWith(autoLockTimeout: AutoLockTimeout.oneMinute),
      const SecuritySettings(
        isPinEnabled: true,
        autoLockTimeout: AutoLockTimeout.oneMinute,
      ),
    );
  });

  test('auto-lock durations and flow modes cover the approved options', () {
    expect(AutoLockTimeout.values.map((value) => value.duration), [
      Duration.zero,
      const Duration(minutes: 1),
      const Duration(minutes: 5),
    ]);
    expect(PinFlowMode.values.map((mode) => mode.name), [
      'unlock',
      'setup',
      'change',
      'disable',
      'reset',
    ]);
  });

  test('verification outcomes have distinct, metadata-based equality', () {
    final until = DateTime.utc(2026);
    expect(const PinVerified(), const PinVerified());
    expect(const PinInvalid(), isNot(const PinNotConfigured()));
    expect(
      const PinIncorrect(remainingAttempts: 3),
      const PinIncorrect(remainingAttempts: 3),
    );
    expect(
      const PinIncorrect(remainingAttempts: 3),
      isNot(const PinIncorrect(remainingAttempts: 2)),
    );
    expect(PinLockedOut(until: until), PinLockedOut(until: until));
    expect(
      PinLockedOut(until: until),
      isNot(PinLockedOut(until: until.add(const Duration(seconds: 1)))),
    );
  });
}
