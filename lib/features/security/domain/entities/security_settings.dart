import 'package:equatable/equatable.dart';

enum AutoLockTimeout {
  immediate(Duration.zero),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5));

  const AutoLockTimeout(this.duration);

  final Duration duration;
}

final class SecuritySettings extends Equatable {
  const SecuritySettings({
    this.isPinEnabled = false,
    bool isBiometricEnabled = false,
    this.autoLockTimeout = AutoLockTimeout.immediate,
  }) : isBiometricEnabled = isPinEnabled && isBiometricEnabled;

  final bool isPinEnabled;
  final bool isBiometricEnabled;
  final AutoLockTimeout autoLockTimeout;

  SecuritySettings copyWith({
    bool? isPinEnabled,
    bool? isBiometricEnabled,
    AutoLockTimeout? autoLockTimeout,
  }) => SecuritySettings(
    isPinEnabled: isPinEnabled ?? this.isPinEnabled,
    isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
    autoLockTimeout: autoLockTimeout ?? this.autoLockTimeout,
  );

  @override
  List<Object> get props => [isPinEnabled, isBiometricEnabled, autoLockTimeout];
}
