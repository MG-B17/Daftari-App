import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_batch.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_eligibility.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_run_result.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_schedule.dart';
import 'package:daftariapp/features/backup/domain/repositories/backup_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  final confirmedAt = DateTime.utc(2026, 11, 24, 12);
  final nextDueAt = DateTime.utc(2026, 11, 25, 12);
  final activeSchedule = BackupScheduleState(
    schedule: BackupSchedule.daily,
    lastConfirmedAt: confirmedAt,
    nextDueAt: nextDueAt,
  );

  group('BackupWorkerPolicy', () {
    test('returns success and resyncs schedule on confirmed run', () {
      final decision = BackupWorkerPolicy.decide(
        Right(
          BackupRunConfirmed(
            batchId: 'batch-1',
            summary: BackupAcknowledgmentSummary(
              acknowledgedRecordCount: 3,
              remainingPendingCount: 0,
              confirmedAt: confirmedAt,
            ),
            scheduleState: activeSchedule,
          ),
        ),
      );

      expect(
        decision,
        BackupWorkerDecision(
          outcome: BackupWorkerOutcome.success,
          scheduleToSync: activeSchedule,
        ),
      );
    });

    test('returns success and resyncs schedule when skipped with no pending changes or not due yet', () {
      for (final reason in [
        BackupIneligibilityReason.noPendingChanges,
        BackupIneligibilityReason.notDueYet,
      ]) {
        final decision = BackupWorkerPolicy.decide(
          Right(
            BackupRunSkipped(reason: reason, scheduleState: activeSchedule),
          ),
        );
        expect(
          decision,
          BackupWorkerDecision(
            outcome: BackupWorkerOutcome.success,
            scheduleToSync: activeSchedule,
          ),
        );
      }
    });

    test('cancels scheduled work when no schedule is configured', () {
      final decision = BackupWorkerPolicy.decide(
        const Right(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.noScheduleConfigured,
          ),
        ),
      );
      expect(
        decision,
        const BackupWorkerDecision(
          outcome: BackupWorkerOutcome.success,
          shouldCancelSchedule: true,
        ),
      );
    });

    test('retries when offline or another backup run is active', () {
      for (final reason in [
        BackupIneligibilityReason.offline,
        BackupIneligibilityReason.alreadyRunning,
      ]) {
        final decision = BackupWorkerPolicy.decide(
          Right(
            BackupRunSkipped(reason: reason, scheduleState: activeSchedule),
          ),
        );
        expect(
          decision,
          const BackupWorkerDecision(outcome: BackupWorkerOutcome.retry),
        );
      }
    });

    test('stops background retry loop on auth, ownership, or inactive-device skips', () {
      for (final reason in [
        BackupIneligibilityReason.signedOut,
        BackupIneligibilityReason.emailNotVerified,
        BackupIneligibilityReason.ledgerUnlinked,
        BackupIneligibilityReason.accountMismatch,
        BackupIneligibilityReason.inactiveDevice,
      ]) {
        final decision = BackupWorkerPolicy.decide(
          Right(
            BackupRunSkipped(reason: reason, scheduleState: activeSchedule),
          ),
        );
        expect(
          decision,
          const BackupWorkerDecision(outcome: BackupWorkerOutcome.success),
        );
      }
    });

    test(
      'retries transient failures and stops on auth/validation failures',
      () {
        for (final code in [
          AppErrorCode.network,
          AppErrorCode.storage,
          AppErrorCode.database,
          AppErrorCode.unexpected,
        ]) {
          expect(
            BackupWorkerPolicy.decide(Left(AppFailure(code))),
            const BackupWorkerDecision(outcome: BackupWorkerOutcome.retry),
          );
        }

        for (final code in [AppErrorCode.auth, AppErrorCode.validation]) {
          expect(
            BackupWorkerPolicy.decide(Left(AppFailure(code))),
            const BackupWorkerDecision(outcome: BackupWorkerOutcome.success),
          );
        }
      },
    );
  });
}
