import 'package:equatable/equatable.dart';

enum BackupSchedule { daily, weekly, monthly }

enum BackupTrigger { manual, scheduled }

/// Persisted scheduling and server-confirmation metadata for cloud backup.
final class BackupScheduleState extends Equatable {
  factory BackupScheduleState({
    BackupSchedule? schedule,
    DateTime? lastConfirmedAt,
    DateTime? nextDueAt,
  }) {
    if ((schedule == null) != (nextDueAt == null)) {
      throw const FormatException(
        'Active backup schedule and nextDueAt must be set or cleared together',
      );
    }
    return BackupScheduleState._(
      schedule: schedule,
      lastConfirmedAt: lastConfirmedAt?.toUtc(),
      nextDueAt: nextDueAt?.toUtc(),
    );
  }

  const BackupScheduleState.initial()
    : schedule = null,
      lastConfirmedAt = null,
      nextDueAt = null;

  const BackupScheduleState._({
    required this.schedule,
    required this.lastConfirmedAt,
    required this.nextDueAt,
  });

  final BackupSchedule? schedule;
  final DateTime? lastConfirmedAt;
  final DateTime? nextDueAt;

  bool get hasSchedule => schedule != null;

  bool get hasConfirmedBackup => lastConfirmedAt != null;

  @override
  List<Object?> get props => [schedule, lastConfirmedAt, nextDueAt];
}
