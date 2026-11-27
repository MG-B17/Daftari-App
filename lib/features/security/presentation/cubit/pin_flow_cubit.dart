import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/pin_flow_mode.dart';
import '../../domain/policies/pin_lockout_policy.dart';
import 'app_lock_cubit.dart';
import 'app_lock_state.dart';

enum PinStep { verify, create, confirm, complete }

enum PinFlowOutcome {
  none,
  setupSuccess,
  changeSuccess,
  disableSuccess,
  failed,
}

final class PinFlowState extends Equatable {
  const PinFlowState({
    required this.step,
    this.count = 0,
    this.mismatch = false,
    this.outcome = PinFlowOutcome.none,
    this.outcomeId = 0,
  });

  final PinStep step;
  final int count;
  final bool mismatch;
  final PinFlowOutcome outcome;
  final int outcomeId;

  @override
  List<Object> get props => [step, count, mismatch, outcome, outcomeId];
}

class PinFlowCubit extends Cubit<PinFlowState> {
  PinFlowCubit(this.lock, this.mode)
    : super(
        PinFlowState(
          step: mode == PinFlowMode.setup ? PinStep.create : PinStep.verify,
        ),
      );

  final AppLockCubit lock;
  final PinFlowMode mode;
  String _digits = '';
  String? _confirmation;
  String? _current;
  bool _recovering = false;
  int _generation = 0;
  int _consumedOutcomeId = 0;

  bool consumeOutcome(int outcomeId) {
    if (outcomeId <= _consumedOutcomeId) return false;
    _consumedOutcomeId = outcomeId;
    return true;
  }

  bool get enabled =>
      state.step != PinStep.complete &&
      !lock.state.busy &&
      !lock.state.obscured &&
      lock.state.message != SecurityMessage.storage &&
      (lock.state.cooldownSeconds == 0 || _recovering);

  Future<void> enter(String digit) async {
    if (!enabled ||
        state.step == PinStep.complete ||
        !RegExp(r'^[0-9]$').hasMatch(digit)) {
      return;
    }
    _digits += digit;
    if (_digits.length < PinLockoutPolicy.pinLength) {
      emit(
        PinFlowState(
          step: state.step,
          count: _digits.length,
          outcomeId: state.outcomeId,
        ),
      );
      return;
    }
    final pin = _digits;
    _digits = '';
    final generation = _generation;
    final step = state.step;
    emit(PinFlowState(step: step, outcomeId: state.outcomeId));
    switch (step) {
      case PinStep.verify:
        final success = mode == PinFlowMode.disable
            ? await lock.disable(pin)
            : await lock.verify(pin, unlock: mode == PinFlowMode.unlock);
        if (isClosed || generation != _generation) return;
        if (success && mode == PinFlowMode.change) {
          _current = pin;
          emit(PinFlowState(step: PinStep.create, outcomeId: state.outcomeId));
        } else if (success) {
          final outcome = mode == PinFlowMode.disable
              ? PinFlowOutcome.disableSuccess
              : PinFlowOutcome.none;
          emit(
            PinFlowState(
              step: PinStep.complete,
              outcome: outcome,
              outcomeId: outcome == PinFlowOutcome.none
                  ? state.outcomeId
                  : state.outcomeId + 1,
            ),
          );
        } else if (mode == PinFlowMode.disable &&
            !lock.state.locked &&
            lock.state.message == SecurityMessage.unavailable) {
          emit(
            PinFlowState(
              step: PinStep.verify,
              outcome: PinFlowOutcome.failed,
              outcomeId: state.outcomeId + 1,
            ),
          );
        }
      case PinStep.create:
        _confirmation = pin;
        emit(PinFlowState(step: PinStep.confirm, outcomeId: state.outcomeId));
      case PinStep.confirm:
        final expected = _confirmation;
        _confirmation = null;
        if (pin != expected) {
          emit(
            PinFlowState(
              step: PinStep.create,
              mismatch: true,
              outcomeId: state.outcomeId,
            ),
          );
          return;
        }
        final success = _recovering
            ? await lock.reset(pin)
            : mode == PinFlowMode.change
            ? await lock.change(_current!, pin)
            : await lock.setup(pin);
        _current = null;
        if (isClosed || generation != _generation) return;
        if (success) {
          final outcome = _recovering || mode == PinFlowMode.unlock
              ? PinFlowOutcome.none
              : mode == PinFlowMode.change
              ? PinFlowOutcome.changeSuccess
              : PinFlowOutcome.setupSuccess;
          emit(
            PinFlowState(
              step: PinStep.complete,
              outcome: outcome,
              outcomeId: outcome == PinFlowOutcome.none
                  ? state.outcomeId
                  : state.outcomeId + 1,
            ),
          );
        } else {
          final nextStep = mode == PinFlowMode.change
              ? PinStep.verify
              : PinStep.create;
          final reportError =
              !_recovering &&
              mode != PinFlowMode.unlock &&
              !lock.state.locked &&
              lock.state.message != SecurityMessage.storage;
          emit(
            PinFlowState(
              step: nextStep,
              outcome: reportError
                  ? PinFlowOutcome.failed
                  : PinFlowOutcome.none,
              outcomeId: reportError ? state.outcomeId + 1 : state.outcomeId,
            ),
          );
        }
      case PinStep.complete:
        break;
    }
  }

  void erase() {
    if (!enabled || _digits.isEmpty) return;
    _digits = _digits.substring(0, _digits.length - 1);
    emit(
      PinFlowState(
        step: state.step,
        count: _digits.length,
        outcomeId: state.outcomeId,
      ),
    );
  }

  void clear() {
    if (!enabled) return;
    _digits = '';
    emit(PinFlowState(step: state.step, outcomeId: state.outcomeId));
  }

  void resetInput() {
    _generation++;
    _digits = '';
    _confirmation = null;
    _current = null;
    _recovering = false;
    lock.cancelRecovery();
    emit(
      PinFlowState(
        step: mode == PinFlowMode.setup ? PinStep.create : PinStep.verify,
        outcomeId: state.outcomeId,
      ),
    );
  }

  Future<void> recover() async {
    if (lock.state.busy) return;
    final generation = _generation;
    final success = await lock.authorizeRecovery();
    if (isClosed || generation != _generation || !success) return;
    _digits = '';
    _current = null;
    _confirmation = null;
    _recovering = true;
    emit(PinFlowState(step: PinStep.create, outcomeId: state.outcomeId));
  }

  @override
  Future<void> close() {
    _digits = '';
    _current = null;
    _confirmation = null;
    lock.cancelRecovery();
    return super.close();
  }
}
