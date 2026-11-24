import 'package:equatable/equatable.dart';

import 'backup_batch.dart';
import 'backup_eligibility.dart';
import 'backup_schedule.dart';

/// Server response for an atomic batch publication request.
sealed class BackupPublicationResult extends Equatable {
  const BackupPublicationResult();

  @override
  List<Object?> get props => [];
}

final class BackupPublicationConfirmed extends BackupPublicationResult {
  BackupPublicationConfirmed({
    required this.batchId,
    required DateTime confirmedAt,
  }) : confirmedAt = confirmedAt.toUtc();

  final String batchId;
  final DateTime confirmedAt;

  @override
  List<Object?> get props => [batchId, confirmedAt];
}

/// Server rejected publication because another device owns cloud backup for
/// this account.
final class BackupPublicationInactiveDevice extends BackupPublicationResult {
  const BackupPublicationInactiveDevice();
}

/// Outcome of a single backup orchestration attempt.
sealed class BackupRunResult extends Equatable {
  const BackupRunResult();

  @override
  List<Object?> get props => [];
}

final class BackupRunConfirmed extends BackupRunResult {
  const BackupRunConfirmed({
    required this.batchId,
    required this.summary,
    required this.scheduleState,
  });

  final String batchId;
  final BackupAcknowledgmentSummary summary;
  final BackupScheduleState scheduleState;

  @override
  List<Object?> get props => [batchId, summary, scheduleState];
}

final class BackupRunSkipped extends BackupRunResult {
  const BackupRunSkipped({required this.reason, this.scheduleState});

  final BackupIneligibilityReason reason;
  final BackupScheduleState? scheduleState;

  @override
  List<Object?> get props => [reason, scheduleState];
}
