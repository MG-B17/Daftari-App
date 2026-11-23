import 'package:equatable/equatable.dart';

import '../../../auth/session/domain/entities/auth_user.dart';

enum BackupStatus { neverBackedUp, pending, running, failed, upToDate }

enum BackupSchedule { daily, weekly, monthly }

/// Presentation snapshot rendered by the backup UI (preview state in Task 1).
final class BackupViewState extends Equatable {
  const BackupViewState({
    required this.status,
    required this.pendingChanges,
    this.schedule,
    this.lastConfirmedAt,
    this.accountEmail,
    this.accountShopName,
    this.isPreview = false,
  });

  /// Default empty preview before cloud backup is wired in later tasks.
  factory BackupViewState.preview({AuthUser? user}) => BackupViewState(
    status: BackupStatus.neverBackedUp,
    pendingChanges: 0,
    accountEmail: user?.email,
    accountShopName: user?.shopName,
    isPreview: true,
  );

  final BackupStatus status;
  final int pendingChanges;
  final BackupSchedule? schedule;
  final DateTime? lastConfirmedAt;
  final String? accountEmail;
  final String? accountShopName;
  final bool isPreview;

  bool get isRunning => status == BackupStatus.running;

  bool get canBackUpNow => pendingChanges > 0 && !isRunning;

  @override
  List<Object?> get props => [
    status,
    pendingChanges,
    schedule,
    lastConfirmedAt,
    accountEmail,
    accountShopName,
    isPreview,
  ];
}
