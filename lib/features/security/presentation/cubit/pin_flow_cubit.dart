import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/pin_flow_mode.dart';
import '../../domain/policies/pin_lockout_policy.dart';
import 'app_lock_cubit.dart';
import 'app_lock_state.dart';

enum PinStep { verify, create, confirm, complete }

final class PinFlowState extends Equatable {
  const PinFlowState({
    required this.step,
    this.count = 0,
    this.mismatch = false,
  });
  final PinStep step;
  final int count;
  final bool mismatch;

  @override
  List<Object> get props => [step, count, mismatch];
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

  bool get enabled =>
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
      emit(PinFlowState(step: state.step, count: _digits.length));
      return;
    }
    final pin = _digits;
    _digits = '';
    final generation = _generation;
    final step = state.step;
    emit(PinFlowState(step: step));
    switch (step) {
      case PinStep.verify:
        final success = mode == PinFlowMode.disable
            ? await lock.disable(pin)
            : await lock.verify(pin, unlock: mode == PinFlowMode.unlock);
        if (isClosed || generation != _generation) return;
        if (success && mode == PinFlowMode.change) {
          _current = pin;
          emit(const PinFlowState(step: PinStep.create));
        } else if (success) {
          emit(const PinFlowState(step: PinStep.complete));
        }
      case PinStep.create:
        _confirmation = pin;
        emit(const PinFlowState(step: PinStep.confirm));
      case PinStep.confirm:
        final expected = _confirmation;
        _confirmation = null;
        if (pin != expected) {
          emit(const PinFlowState(step: PinStep.create, mismatch: true));
          return;
        }
        final success = _recovering
            ? await lock.reset(pin)
            : mode == PinFlowMode.change
            ? await lock.change(_current!, pin)
            : await lock.setup(pin);
        _current = null;
        if (isClosed || generation != _generation) return;
        emit(
          PinFlowState(
            step: success
                ? PinStep.complete
                : mode == PinFlowMode.change
                ? PinStep.verify
                : PinStep.create,
          ),
        );
      case PinStep.complete:
        break;
    }
  }

  void erase() {
    if (!enabled || _digits.isEmpty) return;
    _digits = _digits.substring(0, _digits.length - 1);
    emit(PinFlowState(step: state.step, count: _digits.length));
  }

  void clear() {
    if (!enabled) return;
    _digits = '';
    emit(PinFlowState(step: state.step));
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
    emit(const PinFlowState(step: PinStep.create));
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
