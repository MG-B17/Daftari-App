import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/date_service.dart';
import '../../domain/entities/pin_verify_result.dart';
import '../../domain/entities/security_settings.dart';
import '../../domain/repositories/security_repository.dart';
import 'app_lock_state.dart';

class AppLockCubit extends Cubit<AppLockState> implements Listenable {
  AppLockCubit(this._repository, this._clock) : super(const AppLockState());

  final SecurityRepository _repository;
  final DateService _clock;
  Timer? _cooldownTimer;
  Timer? _backgroundTimer;
  DateTime? _deadline;
  DateTime? _backgroundAt;
  bool _osPrompt = false;
  int _epoch = 0;
  Future<void>? _initializing;
  final ValueNotifier<int> _routing = ValueNotifier(0);

  @override
  void addListener(VoidCallback listener) => _routing.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _routing.removeListener(listener);

  @override
  void emit(AppLockState state) {
    final previous = this.state;
    super.emit(state);
    if (previous.initialized != state.initialized ||
        previous.locked != state.locked) {
      _routing.value++;
    }
  }

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    await _refresh();
    if (!isClosed) {
      emit(
        state.copyWith(
          initialized: true,
          locked:
              state.message == SecurityMessage.storage ||
              state.settings.isPinEnabled,
        ),
      );
    }
  }

  Future<bool> _refresh() async {
    final settings = await _repository.getSettings();
    final lockout = await _repository.getLockoutState();
    if (isClosed) return false;
    if (settings.isLeft() || lockout.isLeft()) {
      _failClosed();
      return false;
    }
    final available = await _repository.canAuthenticateWithBiometrics();
    final device = await _repository.isDeviceLockSupported();
    if (isClosed) return false;
    _deadline = lockout.toNullable()!.lockoutUntil;
    emit(
      state.copyWith(
        settings: settings.toNullable()!,
        biometricAvailable: available.getOrElse((_) => false),
        deviceLockAvailable: device.getOrElse((_) => false),
      ),
    );
    _tick();
    _cooldownTimer?.cancel();
    if (_deadline != null) {
      _cooldownTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tick(),
      );
    }
    return true;
  }

  void _tick() {
    if (isClosed) return;
    final millis = _deadline?.difference(_clock.now()).inMilliseconds ?? 0;
    final seconds = millis <= 0 ? 0 : (millis / 1000).ceil();
    emit(state.copyWith(cooldownSeconds: seconds));
    if (seconds == 0) _cooldownTimer?.cancel();
  }

  void _failClosed() => emit(
    state.copyWith(locked: true, busy: false, message: SecurityMessage.storage),
  );

  Future<bool> _operate(
    Future<Either<AppFailure, bool>> Function() operation, {
    bool unlock = false,
    bool osPrompt = false,
  }) async {
    if (state.busy ||
        !state.initialized ||
        state.message == SecurityMessage.storage) {
      return false;
    }
    final epoch = _epoch;
    _osPrompt = osPrompt;
    emit(state.copyWith(busy: true, message: SecurityMessage.none));
    try {
      final result = await operation();
      if (isClosed) return false;
      if (result.isLeft()) {
        _failClosed();
        return false;
      }
      final success = result.getOrElse((_) => false);
      final refreshed = await _refresh();
      if (isClosed || !refreshed) return false;
      final current = epoch == _epoch;
      emit(
        state.copyWith(
          busy: false,
          locked: !current
              ? state.settings.isPinEnabled || state.locked
              : success && unlock
              ? false
              : state.locked,
          message: success ? SecurityMessage.none : SecurityMessage.unavailable,
        ),
      );
      return success && current;
    } finally {
      _osPrompt = false;
      if (!isClosed && state.busy) emit(state.copyWith(busy: false));
    }
  }

  Future<bool> verify(String pin, {bool unlock = true}) =>
      _verifyResult(() => _repository.verifyPin(pin), unlock: unlock);

  Future<bool> _verifyResult(
    Future<Either<AppFailure, PinVerifyResult>> Function() operation, {
    bool unlock = false,
  }) async {
    if (state.cooldownSeconds > 0) return false;
    PinVerifyResult? outcome;
    final success = await _operate(() async {
      final result = await operation();
      return result.map((value) {
        outcome = value;
        return value is PinVerified;
      });
    }, unlock: unlock);
    if (!isClosed &&
        !success &&
        outcome != null &&
        state.message != SecurityMessage.storage) {
      emit(state.copyWith(message: SecurityMessage.incorrect));
    }
    return success;
  }

  Future<bool> setup(String pin) => _operate(
    () async => (await _repository.setupPin(pin)).map((_) => true),
    unlock: true,
  );

  Future<bool> change(String current, String next) => _verifyResult(
    () => _repository.changePin(currentPin: current, newPin: next),
  );

  Future<bool> disable(String pin) =>
      _verifyResult(() => _repository.disablePin(pin), unlock: true);

  Future<bool> biometric() {
    if (!state.locked || state.cooldownSeconds > 0) return Future.value(false);
    return _operate(
      _repository.authenticateWithBiometrics,
      unlock: true,
      osPrompt: true,
    );
  }

  Future<bool> authorizeRecovery() =>
      _operate(_repository.authorizePinReset, osPrompt: true);

  Future<bool> reset(String pin) => _operate(
    () => _repository.resetPinWithDeviceCredential(pin),
    unlock: true,
    osPrompt: true,
  );

  void cancelRecovery() => _repository.cancelPinReset();

  Future<bool> setBiometric(bool enabled) => _operate(
    () => _repository.setBiometricEnabled(enabled),
    osPrompt: enabled,
  );

  Future<bool> setAutoLock(AutoLockTimeout timeout) => _operate(
    () async =>
        (await _repository.setAutoLockTimeout(timeout)).map((_) => true),
  );

  void lock() {
    _epoch++;
    _repository.cancelPinReset();
    emit(state.copyWith(locked: true, inputRevision: state.inputRevision + 1));
  }

  void lifecycle(AppLifecycleState lifecycle) {
    if (isClosed) return;
    if (lifecycle == AppLifecycleState.resumed) {
      _backgroundTimer?.cancel();
      final since = _backgroundAt;
      if (since != null &&
          state.settings.isPinEnabled &&
          (_clock.now().isBefore(since) ||
              _clock.now().difference(since) >=
                  state.settings.autoLockTimeout.duration)) {
        lock();
      }
      _backgroundAt = null;
      emit(state.copyWith(obscured: false));
      _tick();
      return;
    }
    emit(state.copyWith(obscured: state.settings.isPinEnabled || state.locked));
    // OS prompts cause inactive/resumed without an actual background transition.
    if (lifecycle == AppLifecycleState.inactive && _osPrompt) return;
    if (_backgroundAt != null) return;
    _backgroundAt = _clock.now();
    _epoch++;
    _repository.cancelPinReset();
    emit(state.copyWith(inputRevision: state.inputRevision + 1));
    if (state.settings.isPinEnabled) {
      final timeout = state.settings.autoLockTimeout.duration;
      if (timeout == Duration.zero) {
        lock();
      } else {
        _backgroundTimer = Timer(timeout, lock);
      }
    }
  }

  @override
  Future<void> close() {
    if (isClosed) return Future.value();
    _cooldownTimer?.cancel();
    _backgroundTimer?.cancel();
    _repository.cancelPinReset();
    _routing.dispose();
    return super.close();
  }
}
