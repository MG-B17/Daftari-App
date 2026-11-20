import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:daftariapp/features/security/domain/entities/security_settings.dart';
import 'package:daftariapp/features/security/presentation/cubit/app_lock_cubit.dart';
import 'package:daftariapp/features/security/presentation/cubit/app_lock_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../security_test_setup.dart';

void main() {
  blocTest<AppLockCubit, AppLockState>(
    'startup remains locked when security storage is unavailable',
    build: () => AppLockCubit(
      TestSecurityRepository()..fail = true,
      SecurityTestClock(),
    ),
    act: (cubit) => cubit.initialize(),
    expect: () => [
      isA<AppLockState>()
          .having((s) => s.locked, 'locked', true)
          .having((s) => s.message, 'error', SecurityMessage.storage),
      isA<AppLockState>()
          .having((s) => s.initialized, 'initialized', true)
          .having((s) => s.locked, 'locked', true),
    ],
  );

  test('cold restart always relocks configured PIN, disabled PIN remains usable offline', () async {
    final repository = TestSecurityRepository(pin: '2468');
    var lock = await testAppLock(repository: repository);
    expect(lock.state.locked, isTrue);
    expect(await lock.verify('2468'), isTrue);
    expect(lock.state.locked, isFalse);
    await lock.close();
    lock = await testAppLock(repository: repository);
    expect(lock.state.locked, isTrue);
    await lock.disable('2468');
    await lock.close();
    lock = await testAppLock(repository: repository);
    expect(lock.state.locked, isFalse);
    await lock.close();
  });

  for (final timeout in AutoLockTimeout.values) {
    test(
      '$timeout locks exactly at expiry and never extends on repeated lifecycle events',
      () async {
        final repository = TestSecurityRepository(pin: '2468')
          ..timeout = timeout;
        final clock = SecurityTestClock();
        final lock = AppLockCubit(repository, clock);
        await lock.initialize();
        await lock.verify('2468');
        lock.lifecycle(AppLifecycleState.inactive);
        lock.lifecycle(AppLifecycleState.hidden);
        lock.lifecycle(AppLifecycleState.paused);
        if (timeout != AutoLockTimeout.immediate) {
          expect(lock.state.locked, isFalse);
        }
        clock.time = clock.time.add(timeout.duration);
        lock.lifecycle(AppLifecycleState.resumed);
        expect(lock.state.locked, isTrue);
        expect(lock.state.obscured, isFalse);
        await lock.close();
      },
    );
  }

  test('routing refreshes only when the lock gate changes', () async {
    final repository = TestSecurityRepository(pin: '2468');
    final lock = AppLockCubit(repository, SecurityTestClock());
    var refreshes = 0;
    lock.addListener(() => refreshes++);
    await lock.initialize();
    expect(refreshes, 1);
    expect(await lock.verify('0000'), isFalse);
    expect(refreshes, 1);
    expect(await lock.verify('2468'), isTrue);
    expect(refreshes, 2);
    lock.lock();
    expect(refreshes, 3);
    await lock.close();
  });

  test(
    'inactive with PIN disabled keeps the app visible behind OS surfaces',
    () async {
      final repository = TestSecurityRepository();
      final clock = SecurityTestClock();
      final lock = AppLockCubit(repository, clock);
      await lock.initialize();
      expect(lock.state.settings.isPinEnabled, isFalse);
      lock.lifecycle(AppLifecycleState.inactive);
      expect(lock.state.obscured, isFalse);
      lock.lifecycle(AppLifecycleState.hidden);
      expect(lock.state.obscured, isFalse);
      lock.lifecycle(AppLifecycleState.paused);
      expect(lock.state.obscured, isFalse);
      expect(lock.state.locked, isFalse);
      await lock.close();
    },
  );

  test('inactive with PIN enabled obscures the app', () async {
    final repository = TestSecurityRepository(pin: '2468');
    final lock = await testAppLock(repository: repository);
    await lock.verify('2468');
    lock.lifecycle(AppLifecycleState.inactive);
    expect(lock.state.obscured, isTrue);
    lock.lifecycle(AppLifecycleState.resumed);
    expect(lock.state.obscured, isFalse);
    await lock.close();
  });

  test(
    'resume before timeout preserves session; clock rollback fails closed',
    () async {
      final repository = TestSecurityRepository(pin: '2468')
        ..timeout = AutoLockTimeout.oneMinute;
      final clock = SecurityTestClock();
      final lock = AppLockCubit(repository, clock);
      await lock.initialize();
      await lock.verify('2468');
      lock.lifecycle(AppLifecycleState.paused);
      clock.time = clock.time.add(const Duration(seconds: 59));
      lock.lifecycle(AppLifecycleState.resumed);
      expect(lock.state.locked, isFalse);
      lock.lifecycle(AppLifecycleState.paused);
      clock.time = clock.time.subtract(const Duration(seconds: 1));
      lock.lifecycle(AppLifecycleState.resumed);
      expect(lock.state.locked, isTrue);
      await lock.close();
    },
  );

  test(
    'hash result arriving after background cannot unlock the session',
    () async {
      final barrier = Completer<void>();
      final repository = TestSecurityRepository(pin: '2468')
        ..verificationBarrier = barrier.future;
      final lock = await testAppLock(repository: repository);
      final verification = lock.verify('2468');
      expect(lock.state.busy, isTrue);
      lock.lifecycle(AppLifecycleState.paused);
      barrier.complete();
      expect(await verification, isFalse);
      expect(lock.state.locked, isTrue);
      await lock.close();
    },
  );

  test('parallel calls are ignored while verifying', () async {
    final barrier = Completer<void>();
    final repository = TestSecurityRepository(pin: '2468')
      ..verificationBarrier = barrier.future;
    final lock = await testAppLock(repository: repository);
    final first = lock.verify('2468');
    expect(await lock.verify('2468'), isFalse);
    expect(repository.verificationCalls, 1);
    barrier.complete();
    expect(await first, isTrue);
    await lock.close();
  });

  test(
    'biometric prompt inactive/resumed does not invalidate success',
    () async {
      final repository = TestSecurityRepository(
        pin: '2468',
        biometricEnabled: true,
      )..biometricSuccess = true;
      final lock = await testAppLock(repository: repository);
      final authentication = lock.biometric();
      lock.lifecycle(AppLifecycleState.inactive);
      lock.lifecycle(AppLifecycleState.resumed);
      expect(await authentication, isTrue);
      expect(lock.state.locked, isFalse);
      await lock.close();
    },
  );

  test(
    'biometric prompt paused invalidates result and recovery grant',
    () async {
      final repository = TestSecurityRepository(
        pin: '2468',
        biometricEnabled: true,
      )..biometricSuccess = true;
      final lock = await testAppLock(repository: repository);
      final authentication = lock.biometric();
      lock.lifecycle(AppLifecycleState.inactive);
      lock.lifecycle(AppLifecycleState.paused);
      expect(await authentication, isFalse);
      expect(lock.state.locked, isTrue);
      expect(repository.authorized, isFalse);
      await lock.close();
    },
  );

  testWidgets('cooldown is rehydrated and ticks down to inclusive expiry', (
    tester,
  ) async {
    final clock = SecurityTestClock();
    final repository = TestSecurityRepository(pin: '2468')
      ..attempts = 5
      ..deadline = clock.time.add(const Duration(seconds: 30));
    final lock = AppLockCubit(repository, clock);
    await lock.initialize();
    expect(lock.state.cooldownSeconds, 30);
    expect(await lock.verify('2468'), isFalse);
    expect(await lock.biometric(), isFalse);
    expect(repository.verificationCalls, 0);
    clock.time = clock.time.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    expect(lock.state.cooldownSeconds, 0);
    expect(await lock.verify('2468'), isTrue);
    await lock.close();
  });
}
