import 'package:equatable/equatable.dart';

import '../../../auth/session/domain/entities/auth_user.dart';
import '../../domain/entities/backup_schedule.dart';

export '../../domain/entities/backup_schedule.dart' show BackupSchedule;

enum BackupStatus { neverBackedUp, pending, running, failed, upToDate }

/// Presentation snapshot rendered by the Settings backup section and the
/// Manage Backup screen.
final class BackupViewState extends Equatable {
  const BackupViewState({
    required this.status,
    required this.pendingChanges,
    this.schedule,
    this.lastConfirmedAt,
    this.accountEmail,
    this.accountShopName,
    this.isPreview = false,
    this.isEligibleForManualBackup = true,
  });

  /// Default empty preview used when [BackupCubit] is not mounted (e.g.,
  /// isolated presentation widget tests).
  factory BackupViewState.preview({AuthUser? user}) => BackupViewState(
    status: BackupStatus.neverBackedUp,
    pendingChanges: 0,
    accountEmail: user?.email,
    accountShopName: user?.shopName,
    isPreview: true,
    isEligibleForManualBackup: false,
  );

  final BackupStatus status;
  final int pendingChanges;
  final BackupSchedule? schedule;
  final DateTime? lastConfirmedAt;
  final String? accountEmail;
  final String? accountShopName;
  final bool isPreview;
  final bool isEligibleForManualBackup;

  bool get isRunning => status == BackupStatus.running;

  bool get canBackUpNow =>
      isEligibleForManualBackup && pendingChanges > 0 && !isRunning;

  BackupViewState copyWith({
    BackupStatus? status,
    int? pendingChanges,
    BackupSchedule? Function()? schedule,
    DateTime? Function()? lastConfirmedAt,
    String? Function()? accountEmail,
    String? Function()? accountShopName,
    bool? isPreview,
    bool? isEligibleForManualBackup,
  }) => BackupViewState(
    status: status ?? this.status,
    pendingChanges: pendingChanges ?? this.pendingChanges,
    schedule: schedule != null ? schedule() : this.schedule,
    lastConfirmedAt: lastConfirmedAt != null
        ? lastConfirmedAt()
        : this.lastConfirmedAt,
    accountEmail: accountEmail != null ? accountEmail() : this.accountEmail,
    accountShopName: accountShopName != null
        ? accountShopName()
        : this.accountShopName,
    isPreview: isPreview ?? this.isPreview,
    isEligibleForManualBackup:
        isEligibleForManualBackup ?? this.isEligibleForManualBackup,
  );

  @override
  List<Object?> get props => [
    status,
    pendingChanges,
    schedule,
    lastConfirmedAt,
    accountEmail,
    accountShopName,
    isPreview,
    isEligibleForManualBackup,
  ];
}
