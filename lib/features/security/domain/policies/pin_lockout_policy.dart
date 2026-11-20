import 'package:equatable/equatable.dart';

/// Persistable attempt metadata, separate from the PIN verifier.
final class PinLockoutState extends Equatable {
  factory PinLockoutState({int failedAttempts = 0, DateTime? lockoutUntil}) {
    if (failedAttempts < 0 ||
        failedAttempts > PinLockoutPolicy.maxFailedAttempts ||
        (failedAttempts == PinLockoutPolicy.maxFailedAttempts) !=
            (lockoutUntil != null)) {
      throw const FormatException('Invalid PIN lockout metadata');
    }
    return PinLockoutState._(failedAttempts, lockoutUntil?.toUtc());
  }

  const PinLockoutState.clear() : failedAttempts = 0, lockoutUntil = null;

  const PinLockoutState._(this.failedAttempts, this.lockoutUntil);

  final int failedAttempts;
  final DateTime? lockoutUntil;

  @override
  List<Object?> get props => [failedAttempts, lockoutUntil];
}

/// Pure PIN rules using an explicit clock supplied by the repository.
abstract final class PinLockoutPolicy {
  static const pinLength = 4;
  static const maxFailedAttempts = 5;
  static const cooldown = Duration(seconds: 30);

  static bool isValidPin(String pin) =>
      pin.length == pinLength &&
      pin.codeUnits.every((unit) => unit >= 0x30 && unit <= 0x39);

  /// Rejects malformed input without including it in the exception.
  static void validatePin(String pin) {
    if (!isValidPin(pin)) {
      throw const FormatException('PIN must contain exactly four ASCII digits');
    }
  }

  static bool isLocked(PinLockoutState state, DateTime now) =>
      state.lockoutUntil?.isAfter(now) ?? false;

  static Duration remainingCooldown(PinLockoutState state, DateTime now) =>
      isLocked(state, now)
      ? state.lockoutUntil!.difference(now)
      : Duration.zero;

  /// Clears an expired cooldown, including at its exact deadline.
  static PinLockoutState normalize(PinLockoutState state, DateTime now) =>
      state.lockoutUntil != null && !isLocked(state, now)
      ? const PinLockoutState.clear()
      : state;

  /// Counts a failed verification without extending an active cooldown.
  ///
  /// Invalid-format input is rejected before calling this method. A successful
  /// verification resets to [PinLockoutState.clear] only outside a cooldown.
  static PinLockoutState recordFailure(PinLockoutState state, DateTime now) {
    if (isLocked(state, now)) return state;
    final failures = normalize(state, now).failedAttempts + 1;
    return PinLockoutState(
      failedAttempts: failures,
      lockoutUntil: failures == maxFailedAttempts ? now.add(cooldown) : null,
    );
  }

  static int remainingAttempts(PinLockoutState state, DateTime now) =>
      maxFailedAttempts - normalize(state, now).failedAttempts;
}
