import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../entities/backup_eligibility.dart';
import '../entities/backup_run_result.dart';
import '../entities/backup_schedule.dart';

/// Platform background work scheduler keeping exactly one active OS schedule
/// synchronized with [BackupScheduleState].
abstract interface class BackupScheduler {
  /// Replaces any existing scheduled backup job with one active job targeting
  /// [scheduleState.nextDueAt], or cancels scheduled work when
  /// [scheduleState.hasSchedule] is `false`.
  Future<void> syncSchedule(
    BackupScheduleState scheduleState, {
    required DateTime now,
  });

  /// Cancels any active scheduled backup job.
  Future<void> cancelScheduledBackup();
}

enum BackupWorkerOutcome { success, retry, failure }

final class BackupWorkerDecision extends Equatable {
  const BackupWorkerDecision({
    required this.outcome,
    this.scheduleToSync,
    this.shouldCancelSchedule = false,
  });

  final BackupWorkerOutcome outcome;
  final BackupScheduleState? scheduleToSync;
  final bool shouldCancelSchedule;

  @override
  List<Object?> get props => [outcome, scheduleToSync, shouldCancelSchedule];
}

/// Pure policy translating a scheduled [RunBackupUseCase] outcome into the
/// Android WorkManager worker result and follow-up schedule synchronization.
abstract final class BackupWorkerPolicy {
  static BackupWorkerDecision decide(Either<AppFailure, BackupRunResult> res) {
    return res.fold(_onFailure, _onResult);
  }

  static BackupWorkerDecision _onFailure(AppFailure failure) {
    return switch (failure.errorCode) {
      AppErrorCode.network ||
      AppErrorCode.storage ||
      AppErrorCode.database ||
      AppErrorCode.unexpected => const BackupWorkerDecision(
        outcome: BackupWorkerOutcome.retry,
      ),
      AppErrorCode.auth ||
      AppErrorCode.validation ||
      AppErrorCode.contactPicker => const BackupWorkerDecision(
        outcome: BackupWorkerOutcome.success,
      ),
    };
  }

  static BackupWorkerDecision _onResult(BackupRunResult result) {
    return switch (result) {
      BackupRunConfirmed(:final scheduleState) => BackupWorkerDecision(
        outcome: BackupWorkerOutcome.success,
        scheduleToSync: scheduleState,
      ),
      BackupRunSkipped(:final reason, :final scheduleState) => switch (reason) {
        BackupIneligibilityReason.noScheduleConfigured =>
          const BackupWorkerDecision(
            outcome: BackupWorkerOutcome.success,
            shouldCancelSchedule: true,
          ),
        BackupIneligibilityReason.noPendingChanges ||
        BackupIneligibilityReason.notDueYet => BackupWorkerDecision(
          outcome: BackupWorkerOutcome.success,
          scheduleToSync: scheduleState,
        ),
        BackupIneligibilityReason.offline ||
        BackupIneligibilityReason.alreadyRunning => const BackupWorkerDecision(
          outcome: BackupWorkerOutcome.retry,
        ),
        BackupIneligibilityReason.signedOut ||
        BackupIneligibilityReason.emailNotVerified ||
        BackupIneligibilityReason.ledgerUnlinked ||
        BackupIneligibilityReason.accountMismatch ||
        BackupIneligibilityReason.inactiveDevice => const BackupWorkerDecision(
          outcome: BackupWorkerOutcome.success,
        ),
      },
    };
  }
}
