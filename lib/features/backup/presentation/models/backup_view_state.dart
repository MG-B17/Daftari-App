import 'package:equatable/equatable.dart';

enum BackupStatus { neverBackedUp, pending, running, failed, upToDate }

enum BackupSchedule { daily, weekly, monthly }

/// Presentation snapshot rendered by the backup UI (mock data in Task 1).
final class BackupViewState extends Equatable {
  const BackupViewState({
    required this.status,
    required this.pendingChanges,
    this.schedule,
    this.lastConfirmedAt,
    this.accountEmail,
    this.accountShopName,
  });

  /// Default preview: a linked ledger with local changes waiting for upload
  /// and no schedule chosen yet.
  static final mock = BackupViewState(
    status: BackupStatus.pending,
    pendingChanges: 3,
    lastConfirmedAt: DateTime.now().subtract(const Duration(hours: 2)),
    accountEmail: 'mohamed.store@gmail.com',
    accountShopName: 'بقالة الأمانة - محمد',
  );

  final BackupStatus status;
  final int pendingChanges;
  final BackupSchedule? schedule;
  final DateTime? lastConfirmedAt;
  final String? accountEmail;
  final String? accountShopName;

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
  ];
}
