import 'package:daftariapp/features/security/domain/policies/pin_lockout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 20, 12);

  group('PIN validation', () {
    test('accepts all four-digit ASCII PINs including leading zeroes', () {
      for (var value = 0; value < 10000; value++) {
        expect(PinLockoutPolicy.isValidPin('$value'.padLeft(4, '0')), isTrue);
      }
    });

    test('rejects wrong length, whitespace, Unicode and non-digits', () {
      for (final pin in [
        '',
        '123',
        '12345',
        '1234\n',
        '1234\r\n',
        ' 1234',
        '1234 ',
        '12 4',
        '12a4',
        '-123',
        '١٢٣٤',
        '１２３４',
        '1🔒2',
        '12\u00004',
      ]) {
        expect(PinLockoutPolicy.isValidPin(pin), isFalse);
        expect(() => PinLockoutPolicy.validatePin(pin), throwsFormatException);
      }
    });

    test('validation exceptions do not retain submitted PINs', () {
      try {
        PinLockoutPolicy.validatePin('sensitive-input');
        fail('Expected rejection');
      } on FormatException catch (error) {
        expect(error.source, isNull);
        expect(error.toString(), isNot(contains('sensitive-input')));
      }
    });
  });

  test('fifth failed attempt starts exactly a 30-second cooldown', () {
    var state = const PinLockoutState.clear();
    for (var attempt = 1; attempt <= 5; attempt++) {
      state = PinLockoutPolicy.recordFailure(state, now);
      expect(state.failedAttempts, attempt);
      expect(PinLockoutPolicy.remainingAttempts(state, now), 5 - attempt);
      expect(PinLockoutPolicy.isLocked(state, now), attempt == 5);
    }
    expect(state.lockoutUntil, now.add(const Duration(seconds: 30)));
    expect(
      PinLockoutPolicy.remainingCooldown(state, now),
      const Duration(seconds: 30),
    );
  });

  test('active cooldown cannot be extended by repeated submissions', () {
    final state = PinLockoutState(
      failedAttempts: 5,
      lockoutUntil: now.add(const Duration(seconds: 30)),
    );
    final later = now.add(const Duration(seconds: 29));
    expect(PinLockoutPolicy.recordFailure(state, later), same(state));
    expect(
      PinLockoutPolicy.remainingCooldown(state, later),
      const Duration(seconds: 1),
    );
    expect(
      PinLockoutPolicy.isLocked(
        state,
        state.lockoutUntil!.subtract(const Duration(microseconds: 1)),
      ),
      isTrue,
    );
  });

  test(
    'expiry is inclusive, resets attempts, and starts a new failure cycle',
    () {
      final until = now.add(const Duration(seconds: 30));
      final state = PinLockoutState(failedAttempts: 5, lockoutUntil: until);
      for (final time in [until, until.add(const Duration(days: 1))]) {
        expect(PinLockoutPolicy.isLocked(state, time), isFalse);
        expect(PinLockoutPolicy.remainingCooldown(state, time), Duration.zero);
        expect(PinLockoutPolicy.remainingAttempts(state, time), 5);
        expect(
          PinLockoutPolicy.normalize(state, time),
          const PinLockoutState.clear(),
        );
        expect(
          PinLockoutPolicy.recordFailure(state, time),
          PinLockoutState(failedAttempts: 1),
        );
      }
    },
  );

  test(
    'rehydrated cooldown retains deadline and fails closed on clock rollback',
    () {
      final original = PinLockoutState(
        failedAttempts: 5,
        lockoutUntil: now.add(const Duration(seconds: 30)),
      );
      final restored = PinLockoutState(
        failedAttempts: original.failedAttempts,
        lockoutUntil: DateTime.parse(original.lockoutUntil!.toIso8601String()),
      );
      expect(restored, original);
      expect(restored.hashCode, original.hashCode);
      expect(
        PinLockoutPolicy.isLocked(
          restored,
          now.subtract(const Duration(hours: 1)),
        ),
        isTrue,
      );
      expect(restored.lockoutUntil!.isUtc, isTrue);
    },
  );

  test(
    'partial failures survive normalization and clear state resets them',
    () {
      final partial = PinLockoutState(failedAttempts: 4);
      expect(PinLockoutPolicy.normalize(partial, now), same(partial));
      expect(
        PinLockoutPolicy.remainingAttempts(const PinLockoutState.clear(), now),
        5,
      );
      expect(PinLockoutPolicy.remainingCooldown(partial, now), Duration.zero);
    },
  );

  test(
    'invalid persisted attempt metadata is rejected rather than unlocked',
    () {
      for (final count in [-1, 6, 100]) {
        expect(
          () => PinLockoutState(failedAttempts: count),
          throwsFormatException,
        );
      }
      expect(() => PinLockoutState(failedAttempts: 5), throwsFormatException);
      expect(
        () => PinLockoutState(failedAttempts: 4, lockoutUntil: now),
        throwsFormatException,
      );
      expect(() => PinLockoutState(lockoutUntil: now), throwsFormatException);
    },
  );
}
