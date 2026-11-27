import 'package:daftariapp/features/security/domain/entities/pin_flow_mode.dart';
import 'package:daftariapp/features/security/presentation/cubit/app_lock_cubit.dart';
import 'package:daftariapp/features/security/presentation/cubit/pin_flow_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../security_test_setup.dart';

void main() {
  late TestSecurityRepository repository;
  late AppLockCubit lock;
  late PinFlowCubit flow;
  setUp(() async {
    repository = TestSecurityRepository();
    lock = await testAppLock(repository: repository);
    flow = PinFlowCubit(lock, PinFlowMode.setup);
  });
  tearDown(() async {
    await flow.close();
    await lock.close();
  });
  Future<void> digits(String value) async {
    for (final digit in value.split('')) {
      await flow.enter(digit);
    }
  }

  test(
    'clearing preserves create/confirm phase and candidate, never emits PIN',
    () async {
      await digits('12');
      expect(flow.state.count, 2);
      expect(flow.state.toString(), isNot(contains('12')));
      flow.erase();
      expect(flow.state.count, 1);
      flow.clear();
      expect(flow.state.count, 0);
      await digits('9876');
      await digits('98');
      flow.clear();
      expect(flow.state.step, PinStep.confirm);
      await digits('9876');
      expect(flow.state.step, PinStep.complete);
      expect(repository.pin, '9876');
    },
  );

  test('mismatch discards candidate and requires new confirmation', () async {
    await digits('9876');
    await digits('0000');
    expect(flow.state.mismatch, isTrue);
    expect(flow.state.step, PinStep.create);
    expect(repository.pin, isNull);
    flow.clear();
    expect(flow.state.mismatch, isFalse);
  });

  test(
    'change verifies old PIN and persists replacement; disable verifies',
    () async {
      await flow.close();
      repository.pin = '1234';
      flow = PinFlowCubit(lock, PinFlowMode.change);
      await digits('0000');
      expect(flow.state.step, PinStep.verify);
      await digits('1234');
      expect(flow.state.step, PinStep.create);
      await digits('9876');
      await digits('9876');
      expect(repository.pin, '9876');
      await flow.close();
      flow = PinFlowCubit(lock, PinFlowMode.disable);
      await digits('9876');
      expect(repository.pin, isNull);
    },
  );

  test(
    'reset input erases old/candidate PINs and recovery authorization',
    () async {
      repository.pin = '1234';
      repository.recoverySuccess = true;
      await flow.recover();
      await digits('9876');
      flow.resetInput();
      expect(repository.authorized, isFalse);
      expect(flow.state.step, PinStep.create);
      expect(flow.state.count, 0);
    },
  );

  test('explicit setup, change and disable emit one-shot terminal outcomes while unlock stays silent', () async {
    await digits('9876');
    await digits('9876');
    expect(flow.state.step, PinStep.complete);
    expect(flow.state.outcome, PinFlowOutcome.setupSuccess);
    expect(flow.state.outcomeId, 1);
    expect(flow.enabled, isFalse);
    expect(flow.consumeOutcome(1), isTrue);
    expect(flow.consumeOutcome(1), isFalse);

    await flow.close();
    flow = PinFlowCubit(lock, PinFlowMode.change);
    await digits('9876');
    await digits('2468');
    await digits('2468');
    expect(flow.state.step, PinStep.complete);
    expect(flow.state.outcome, PinFlowOutcome.changeSuccess);
    expect(flow.state.outcomeId, 1);

    await flow.close();
    flow = PinFlowCubit(lock, PinFlowMode.disable);
    await digits('2468');
    expect(flow.state.step, PinStep.complete);
    expect(flow.state.outcome, PinFlowOutcome.disableSuccess);
    expect(flow.state.outcomeId, 1);

    await flow.close();
    repository.pin = '2468';
    lock.lock();
    flow = PinFlowCubit(lock, PinFlowMode.unlock);
    await digits('2468');
    expect(flow.state.step, PinStep.complete);
    expect(flow.state.outcome, PinFlowOutcome.none);
    expect(flow.state.outcomeId, 0);
  });

  test(
    'storage failure during setup locks fail-closed without dialog outcome',
    () async {
      repository.fail = true;
      await digits('9876');
      await digits('9876');
      expect(lock.state.locked, isTrue);
      expect(flow.state.outcome, PinFlowOutcome.none);
      expect(flow.state.outcomeId, 0);
    },
  );
}
