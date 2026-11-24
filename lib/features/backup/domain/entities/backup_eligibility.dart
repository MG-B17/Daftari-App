import 'package:equatable/equatable.dart';

enum BackupIneligibilityReason {
  alreadyRunning,
  noScheduleConfigured,
  notDueYet,
  signedOut,
  emailNotVerified,
  ledgerUnlinked,
  accountMismatch,
  inactiveDevice,
  noPendingChanges,
  offline,
}

/// Snapshot of local account, device, ledger and runtime state evaluated by
/// both manual and scheduled backup entry points.
final class BackupEligibilityContext extends Equatable {
  const BackupEligibilityContext({
    required this.authenticatedUserId,
    required this.isEmailVerified,
    required this.linkedOwnerUserId,
    required this.deviceId,
    required this.isActiveDevice,
    required this.pendingChangesCount,
    required this.hasConnectivity,
    this.isBackupRunning = false,
    this.sessionInstanceId,
  }) : assert(pendingChangesCount >= 0);

  final String? authenticatedUserId;
  final bool isEmailVerified;
  final String? linkedOwnerUserId;
  final String? deviceId;
  final bool isActiveDevice;
  final int pendingChangesCount;
  final bool hasConnectivity;
  final bool isBackupRunning;

  /// Optional opaque identifier of the active session instance (including
  /// cross-isolate session epoch and persisted session binding) captured when
  /// a backup run is authorized.
  final String? sessionInstanceId;

  bool get hasAuthenticatedUser => _isNonBlank(authenticatedUserId);

  bool get hasLinkedOwner => _isNonBlank(linkedOwnerUserId);

  bool get isMatchingLinkedAccount =>
      hasAuthenticatedUser &&
      hasLinkedOwner &&
      authenticatedUserId == linkedOwnerUserId;

  bool get hasDeviceId => _isNonBlank(deviceId);

  bool get hasPendingChanges => pendingChangesCount > 0;

  BackupEligibilityContext copyWith({
    bool? isBackupRunning,
    String? Function()? sessionInstanceId,
  }) => BackupEligibilityContext(
    authenticatedUserId: authenticatedUserId,
    isEmailVerified: isEmailVerified,
    linkedOwnerUserId: linkedOwnerUserId,
    deviceId: deviceId,
    isActiveDevice: isActiveDevice,
    pendingChangesCount: pendingChangesCount,
    hasConnectivity: hasConnectivity,
    isBackupRunning: isBackupRunning ?? this.isBackupRunning,
    sessionInstanceId: sessionInstanceId != null
        ? sessionInstanceId()
        : this.sessionInstanceId,
  );

  static bool _isNonBlank(String? value) =>
      value != null && value.trim().isNotEmpty;

  @override
  List<Object?> get props => [
    authenticatedUserId,
    isEmailVerified,
    linkedOwnerUserId,
    deviceId,
    isActiveDevice,
    pendingChangesCount,
    hasConnectivity,
    isBackupRunning,
    sessionInstanceId,
  ];
}

final class BackupEligibilityDecision extends Equatable {
  const BackupEligibilityDecision.eligible() : isEligible = true, reason = null;

  const BackupEligibilityDecision.ineligible(
    BackupIneligibilityReason this.reason,
  ) : isEligible = false;

  final bool isEligible;
  final BackupIneligibilityReason? reason;

  @override
  List<Object?> get props => [isEligible, reason];
}
