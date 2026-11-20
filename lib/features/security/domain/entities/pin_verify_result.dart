import 'package:equatable/equatable.dart';

sealed class PinVerifyResult extends Equatable {
  const PinVerifyResult();

  @override
  List<Object> get props => [];
}

final class PinVerified extends PinVerifyResult {
  const PinVerified();
}

final class PinIncorrect extends PinVerifyResult {
  const PinIncorrect({required this.remainingAttempts});

  final int remainingAttempts;

  @override
  List<Object> get props => [remainingAttempts];
}

final class PinLockedOut extends PinVerifyResult {
  const PinLockedOut({required this.until});

  final DateTime until;

  @override
  List<Object> get props => [until];
}

final class PinInvalid extends PinVerifyResult {
  const PinInvalid();
}

final class PinNotConfigured extends PinVerifyResult {
  const PinNotConfigured();
}
