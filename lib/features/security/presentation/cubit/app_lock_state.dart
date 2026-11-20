import 'package:equatable/equatable.dart';

import '../../domain/entities/security_settings.dart';

enum SecurityMessage { none, incorrect, mismatch, unavailable, storage }

final class AppLockState extends Equatable {
  const AppLockState({
    this.initialized = false,
    this.locked = true,
    this.busy = false,
    this.obscured = false,
    this.settings = const SecuritySettings(),
    this.biometricAvailable = false,
    this.deviceLockAvailable = false,
    this.cooldownSeconds = 0,
    this.message = SecurityMessage.none,
    this.inputRevision = 0,
  });

  final bool initialized;
  final bool locked;
  final bool busy;
  final bool obscured;
  final SecuritySettings settings;
  final bool biometricAvailable;
  final bool deviceLockAvailable;
  final int cooldownSeconds;
  final SecurityMessage message;
  final int inputRevision;

  AppLockState copyWith({
    bool? initialized,
    bool? locked,
    bool? busy,
    bool? obscured,
    SecuritySettings? settings,
    bool? biometricAvailable,
    bool? deviceLockAvailable,
    int? cooldownSeconds,
    SecurityMessage? message,
    int? inputRevision,
  }) => AppLockState(
    initialized: initialized ?? this.initialized,
    locked: locked ?? this.locked,
    busy: busy ?? this.busy,
    obscured: obscured ?? this.obscured,
    settings: settings ?? this.settings,
    biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    deviceLockAvailable: deviceLockAvailable ?? this.deviceLockAvailable,
    cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
    message: message ?? this.message,
    inputRevision: inputRevision ?? this.inputRevision,
  );

  @override
  List<Object> get props => [
    initialized,
    locked,
    busy,
    obscured,
    settings,
    biometricAvailable,
    deviceLockAvailable,
    cooldownSeconds,
    message,
    inputRevision,
  ];
}
