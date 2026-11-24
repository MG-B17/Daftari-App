import 'dart:async';

import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_batch.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_eligibility.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_run_result.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_schedule.dart';
import 'package:daftariapp/features/backup/domain/policies/backup_schedule_policy.dart';
import 'package:daftariapp/features/backup/domain/usecases/run_backup_usecase.dart';
import 'package:daftariapp/features/backup/domain/usecases/update_backup_schedule_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'backup_domain_fakes.dart';

void main() {
  late FakeDateService clock;
  late InMemoryBackupRunLock runLock;
  late FakeBackupLocalStore localStore;
  late FakeBackupCloudPublisher cloudPublisher;
  late int batchCounter;
  late RunBackupUseCase runBackup;
  late UpdateBackupScheduleUseCase updateSchedule;

  setUp(() {
    clock = FakeDateService(DateTime.utc(2026, 11, 23, 10));
    runLock = InMemoryBackupRunLock();
    localStore = FakeBackupLocalStore(runLockForRunningFlag: runLock);
    cloudPublisher = FakeBackupCloudPublisher(
      serverTime: DateTime.utc(2026, 11, 23, 10, 0, 5),
    );
    batchCounter = 0;
    runBackup = RunBackupUseCase(
      localStore: localStore,
      cloudPublisher: cloudPublisher,
      runLock: runLock,
      dateService: clock,
      generateBatchId: () => 'batch-${++batchCounter}',
    );
    updateSchedule = UpdateBackupScheduleUseCase(
      localStore: localStore,
      dateService: clock,
    );
  });

  group('Unchanged data', () {
    test(
      'empty ledger produces zero upload requests for manual and scheduled',
      () async {
        localStore.scheduleState = BackupScheduleState(
          schedule: BackupSchedule.daily,
          nextDueAt: clock.current,
        );

        final manual = await runBackup(trigger: BackupTrigger.manual);
        expect(
          manual,
          Right<AppFailure, BackupRunResult>(
            BackupRunSkipped(
              reason: BackupIneligibilityReason.noPendingChanges,
              scheduleState: localStore.scheduleState,
            ),
          ),
        );
        expect(cloudPublisher.publishAttempts, 0);
        expect(localStore.captureCalls, 0);
        expect(localStore.scheduleState.lastConfirmedAt, isNull);

        final scheduled = await runBackup(trigger: BackupTrigger.scheduled);
        expect(
          scheduled,
          Right<AppFailure, BackupRunResult>(
            BackupRunSkipped(
              reason: BackupIneligibilityReason.noPendingChanges,
              scheduleState: BackupScheduleState(
                schedule: BackupSchedule.daily,
                nextDueAt: DateTime.utc(2026, 11, 24, 10),
              ),
            ),
          ),
        );
        expect(cloudPublisher.publishAttempts, 0);
        expect(localStore.scheduleState.lastConfirmedAt, isNull);
      },
    );

    test('overdue unchanged ledger advances nextDueAt without causing a retry loop and preserves lastConfirmedAt', () async {
      final previousConfirmed = DateTime.utc(2026, 11, 20, 10);
      localStore.putCustomer(testCustomer(), acknowledgedRevision: 1);
      localStore.scheduleState = BackupScheduleState(
        schedule: BackupSchedule.daily,
        lastConfirmedAt: previousConfirmed,
        nextDueAt: DateTime.utc(2026, 11, 21, 10),
      );

      // First overdue check: skips upload, preserves lastConfirmedAt, advances nextDueAt.
      final first = await runBackup(trigger: BackupTrigger.scheduled);
      expect(
        first,
        Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.noPendingChanges,
            scheduleState: BackupScheduleState(
              schedule: BackupSchedule.daily,
              lastConfirmedAt: previousConfirmed,
              nextDueAt: DateTime.utc(2026, 11, 24, 10),
            ),
          ),
        ),
      );
      expect(cloudPublisher.publishAttempts, 0);
      expect(localStore.acknowledgeCalls, 0);
      expect(localStore.scheduleWriteCount, 1);

      // Immediate follow-up check (e.g. next launch 1 minute later): not due -> no loop.
      clock.current = clock.current.add(const Duration(minutes: 1));
      final second = await runBackup(trigger: BackupTrigger.scheduled);
      expect(
        second,
        Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.notDueYet,
            scheduleState: localStore.scheduleState,
          ),
        ),
      );
      expect(cloudPublisher.publishAttempts, 0);
      expect(localStore.scheduleWriteCount, 1);
    });

    test(
      'empty captured batch skips upload without calling cloud publisher',
      () async {
        localStore.putCustomer(testCustomer());
        localStore.forceEmptyCaptureOnce = true;

        final result = await runBackup(trigger: BackupTrigger.manual);
        expect(
          result,
          const Right<AppFailure, BackupRunResult>(
            BackupRunSkipped(
              reason: BackupIneligibilityReason.noPendingChanges,
              scheduleState: BackupScheduleState.initial(),
            ),
          ),
        );
        expect(cloudPublisher.publishAttempts, 0);
        expect(localStore.acknowledgeCalls, 0);
      },
    );
  });

  group('Overlapping triggers', () {
    test('manual and scheduled triggers overlapping an active run return alreadyRunning with zero duplicate uploads', () async {
      localStore.putCustomer(testCustomer());
      localStore.scheduleState = BackupScheduleState(
        schedule: BackupSchedule.daily,
        nextDueAt: clock.current,
      );

      final publishStarted = Completer<void>();
      final releasePublish = Completer<void>();
      cloudPublisher.onPublishStarted = (_) async {
        publishStarted.complete();
        await releasePublish.future;
      };

      final firstFuture = runBackup(trigger: BackupTrigger.manual);
      await publishStarted.future;
      expect(runLock.isLocked, isTrue);

      // Concurrent manual and scheduled triggers both skip immediately.
      final overlappingManual = await runBackup(trigger: BackupTrigger.manual);
      final overlappingScheduled = await runBackup(
        trigger: BackupTrigger.scheduled,
      );

      expect(
        overlappingManual,
        const Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(reason: BackupIneligibilityReason.alreadyRunning),
        ),
      );
      expect(
        overlappingScheduled,
        const Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(reason: BackupIneligibilityReason.alreadyRunning),
        ),
      );
      expect(cloudPublisher.publishAttempts, 1);

      releasePublish.complete();
      final firstResult = await firstFuture;
      expect(firstResult.isRight(), isTrue);
      expect(runLock.isLocked, isFalse);
      expect(runLock.releaseCount, 1);
    });

    test(
      'lock is always released after upload failure so next trigger can run',
      () async {
        localStore.putCustomer(testCustomer());
        cloudPublisher.nextFailure = const AppFailure(AppErrorCode.network);

        final failed = await runBackup(trigger: BackupTrigger.manual);
        expect(
          failed,
          const Left<AppFailure, BackupRunResult>(
            AppFailure(AppErrorCode.network),
          ),
        );
        expect(runLock.isLocked, isFalse);
        expect(runLock.releaseCount, 1);

        cloudPublisher.nextFailure = null;
        final retried = await runBackup(trigger: BackupTrigger.manual);
        expect(retried.isRight(), isTrue);
        expect(cloudPublisher.distinctServerCommits, 1);
        expect(runLock.isLocked, isFalse);
      },
    );
  });

  group('Edits and deletions during upload', () {
    test('editing transaction 100 -> 150 and adding a transaction during upload keeps new changes pending for next backup exactly once', () async {
      localStore.putCustomer(testCustomer(), acknowledgedRevision: 1);
      localStore.putTransaction(
        testTransaction(id: 'tx-1', amountPiasters: 10000),
      );

      final publishStarted = Completer<void>();
      final releasePublish = Completer<void>();
      cloudPublisher.onPublishStarted = (_) async {
        if (!publishStarted.isCompleted) {
          publishStarted.complete();
          await releasePublish.future;
        }
      };

      final firstRunFuture = runBackup(trigger: BackupTrigger.manual);
      await publishStarted.future;

      // Mutate locally while batch-1 (containing tx-1 = 10000) is uploading.
      localStore.editTransactionLocally(
        transactionId: 'tx-1',
        newAmountPiasters: 15000,
        auditId: 'audit-edit-1',
        editedAt: DateTime.utc(2026, 11, 23, 10, 0, 2),
      );
      localStore.putTransaction(
        testTransaction(
          id: 'tx-2',
          amountPiasters: 5000,
          timestamp: DateTime.utc(2026, 11, 23, 10, 0, 3),
        ),
      );

      releasePublish.complete();
      final firstRun = await firstRunFuture;

      // First confirmed backup contains 10000; local retains 15000 and 3 pending records.
      expect(
        firstRun,
        Right<AppFailure, BackupRunResult>(
          BackupRunConfirmed(
            batchId: 'batch-1',
            summary: BackupAcknowledgmentSummary(
              acknowledgedRecordCount: 0,
              remainingPendingCount: 3,
              confirmedAt: DateTime.utc(2026, 11, 23, 10, 0, 5),
            ),
            scheduleState: BackupScheduleState(
              lastConfirmedAt: DateTime.utc(2026, 11, 23, 10, 0, 5),
            ),
          ),
        ),
      );
      expect(cloudPublisher.cloudTransactions['tx-1']!.amountPiasters, 10000);
      expect(localStore.transactions['tx-1']!.amountPiasters, 15000);
      expect(localStore.countPendingChanges(), 3);

      // Next successful backup captures edit, new tx and audit entry exactly once.
      cloudPublisher.onPublishStarted = null;
      cloudPublisher.serverTime = DateTime.utc(2026, 11, 23, 10, 1);
      final secondRun = await runBackup(trigger: BackupTrigger.manual);

      expect(
        secondRun,
        Right<AppFailure, BackupRunResult>(
          BackupRunConfirmed(
            batchId: 'batch-2',
            summary: BackupAcknowledgmentSummary(
              acknowledgedRecordCount: 3,
              remainingPendingCount: 0,
              confirmedAt: DateTime.utc(2026, 11, 23, 10, 1),
            ),
            scheduleState: BackupScheduleState(
              lastConfirmedAt: DateTime.utc(2026, 11, 23, 10, 1),
            ),
          ),
        ),
      );

      final secondBatch = cloudPublisher.publishedBatches[1];
      expect(secondBatch.customers, isEmpty);
      expect(secondBatch.transactions.map((t) => t.id), ['tx-1', 'tx-2']);
      expect(secondBatch.transactions.first.amountPiasters, 15000);
      expect(secondBatch.transactions.first.localRevision, 2);
      expect(secondBatch.auditLogs.map((a) => a.id), ['audit-edit-1']);
      expect(secondBatch.auditLogs.first.previousAmountPiasters, 10000);
      expect(cloudPublisher.cloudTransactions['tx-1']!.amountPiasters, 15000);
      expect(cloudPublisher.cloudTransactions['tx-2']!.amountPiasters, 5000);
      expect(cloudPublisher.cloudAuditLogs.length, 1);
      expect(localStore.countPendingChanges(), 0);

      // Third run skips with zero upload requests.
      final thirdRun = await runBackup(trigger: BackupTrigger.manual);
      expect(
        thirdRun,
        Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.noPendingChanges,
            scheduleState: localStore.scheduleState,
          ),
        ),
      );
      expect(cloudPublisher.publishAttempts, 2);
    });

    test('soft-deleting a transaction during upload keeps tombstone and delete audit history pending together', () async {
      localStore.putCustomer(testCustomer(), acknowledgedRevision: 1);
      localStore.putTransaction(
        testTransaction(id: 'tx-1', amountPiasters: 10000),
      );

      final publishStarted = Completer<void>();
      final releasePublish = Completer<void>();
      cloudPublisher.onPublishStarted = (_) async {
        if (!publishStarted.isCompleted) {
          publishStarted.complete();
          await releasePublish.future;
        }
      };

      final firstRunFuture = runBackup(trigger: BackupTrigger.manual);
      await publishStarted.future;

      final deletedAt = DateTime.utc(2026, 11, 23, 10, 0, 2);
      localStore.softDeleteTransactionLocally(
        transactionId: 'tx-1',
        auditId: 'audit-del-1',
        deletedAt: deletedAt,
      );

      releasePublish.complete();
      final firstRun = await firstRunFuture;
      expect(firstRun.isRight(), isTrue);
      expect(cloudPublisher.cloudTransactions['tx-1']!.isDeleted, isFalse);
      expect(localStore.countPendingChanges(), 2);

      cloudPublisher.onPublishStarted = null;
      cloudPublisher.serverTime = DateTime.utc(2026, 11, 23, 10, 1);
      final secondRun = await runBackup(trigger: BackupTrigger.manual);
      expect(secondRun.isRight(), isTrue);

      final secondBatch = cloudPublisher.publishedBatches[1];
      expect(secondBatch.transactions.single.id, 'tx-1');
      expect(secondBatch.transactions.single.deletedAt, deletedAt);
      expect(secondBatch.auditLogs.single.id, 'audit-del-1');
      expect(secondBatch.auditLogs.single.action, BackupAuditAction.delete);
      expect(cloudPublisher.cloudTransactions['tx-1']!.isDeleted, isTrue);
      expect(cloudPublisher.cloudAuditLogs['audit-del-1'], isNotNull);
      expect(localStore.countPendingChanges(), 0);
    });
  });

  group('Interruptions, recovery, device authority and session isolation', () {
    test('interruption before publication preserves previous cloud contents and confirmed timestamp', () async {
      final previousConfirmed = DateTime.utc(2026, 11, 22, 10);
      localStore.putCustomer(testCustomer(), acknowledgedRevision: 1);
      localStore.putTransaction(
        testTransaction(id: 'tx-1', amountPiasters: 10000),
        acknowledgedRevision: 1,
      );
      cloudPublisher.cloudCustomers['cust-1'] = testCustomer();
      cloudPublisher.cloudTransactions['tx-1'] = testTransaction(
        id: 'tx-1',
        amountPiasters: 10000,
      );
      localStore.scheduleState = BackupScheduleState(
        schedule: BackupSchedule.daily,
        lastConfirmedAt: previousConfirmed,
        nextDueAt: DateTime.utc(2026, 11, 23, 10),
      );

      localStore.editTransactionLocally(
        transactionId: 'tx-1',
        newAmountPiasters: 20000,
        auditId: 'audit-1',
        editedAt: DateTime.utc(2026, 11, 23, 9),
      );
      cloudPublisher.nextFailure = const AppFailure(AppErrorCode.network);

      final failed = await runBackup(trigger: BackupTrigger.scheduled);
      expect(
        failed,
        const Left<AppFailure, BackupRunResult>(
          AppFailure(AppErrorCode.network),
        ),
      );
      expect(cloudPublisher.cloudTransactions['tx-1']!.amountPiasters, 10000);
      expect(cloudPublisher.distinctServerCommits, 0);
      expect(localStore.scheduleState.lastConfirmedAt, previousConfirmed);
      expect(
        localStore.scheduleState.nextDueAt,
        DateTime.utc(2026, 11, 23, 10),
      );
      expect(localStore.acknowledgeCalls, 0);
    });

    test('lost acknowledgment recovers original server confirmation without republishing and leaves newer edits pending for next batch', () async {
      final previousConfirmed = DateTime.utc(2026, 11, 22, 10);
      final originalServerConfirmation = DateTime.utc(2026, 11, 23, 10, 0, 5);
      localStore.scheduleState = BackupScheduleState(
        schedule: BackupSchedule.daily,
        lastConfirmedAt: previousConfirmed,
        nextDueAt: DateTime.utc(2026, 11, 23, 10),
      );
      localStore.putCustomer(testCustomer(), acknowledgedRevision: 1);
      localStore.putTransaction(
        testTransaction(id: 'tx-1', amountPiasters: 10000),
      );
      cloudPublisher.serverTime = originalServerConfirmation;

      // Server commits batch-1 at originalServerConfirmation, then local ack fails.
      localStore.acknowledgeFailure = const AppFailure(AppErrorCode.database);
      final interrupted = await runBackup(trigger: BackupTrigger.scheduled);
      expect(
        interrupted,
        const Left<AppFailure, BackupRunResult>(
          AppFailure(AppErrorCode.database),
        ),
      );
      expect(cloudPublisher.distinctServerCommits, 1);
      expect(localStore.inFlightBatch?.batchId, 'batch-1');
      expect(localStore.scheduleState.lastConfirmedAt, previousConfirmed);
      expect(localStore.countPendingChanges(), 1);

      // User edits tx-1 locally between attempts (rev 1 -> 2 + edit audit log).
      localStore.editTransactionLocally(
        transactionId: 'tx-1',
        newAmountPiasters: 15000,
        auditId: 'audit-edit-1',
        editedAt: DateTime.utc(2026, 11, 23, 10, 2),
      );

      // Retry with a fresh RunBackupUseCase instance and a later server clock.
      localStore.acknowledgeFailure = null;
      clock.current = DateTime.utc(2026, 11, 23, 10, 5);
      cloudPublisher.serverTime = DateTime.utc(2026, 11, 23, 10, 5, 10);
      var freshCounter = 100;
      final restartedRunBackup = RunBackupUseCase(
        localStore: localStore,
        cloudPublisher: cloudPublisher,
        runLock: runLock,
        dateService: clock,
        generateBatchId: () => 'restarted-batch-${++freshCounter}',
      );

      final recovered = await restartedRunBackup(
        trigger: BackupTrigger.scheduled,
      );
      expect(
        recovered,
        Right<AppFailure, BackupRunResult>(
          BackupRunConfirmed(
            batchId: 'batch-1',
            summary: BackupAcknowledgmentSummary(
              acknowledgedRecordCount: 0,
              remainingPendingCount: 2,
              confirmedAt: originalServerConfirmation,
            ),
            scheduleState: BackupScheduleState(
              schedule: BackupSchedule.daily,
              lastConfirmedAt: originalServerConfirmation,
              nextDueAt: DateTime.utc(2026, 11, 24, 10, 0, 5),
            ),
          ),
        ),
      );
      // Zero duplicate server commits; original confirmation recovered.
      expect(cloudPublisher.distinctServerCommits, 1);
      expect(cloudPublisher.publishAttempts, 1);
      expect(cloudPublisher.findConfirmationCalls, 1);
      expect(cloudPublisher.cloudTransactions['tx-1']!.amountPiasters, 10000);
      expect(localStore.inFlightBatch, isNull);
      expect(
        localStore.scheduleState.lastConfirmedAt,
        originalServerConfirmation,
      );
      expect(localStore.countPendingChanges(), 2);

      // Subsequent manual run captures the newer edit + audit log in batch #2.
      final secondBatchTime = DateTime.utc(2026, 11, 23, 10, 6);
      cloudPublisher.serverTime = secondBatchTime;
      final subsequent = await restartedRunBackup(
        trigger: BackupTrigger.manual,
      );
      expect(
        subsequent,
        Right<AppFailure, BackupRunResult>(
          BackupRunConfirmed(
            batchId: 'restarted-batch-101',
            summary: BackupAcknowledgmentSummary(
              acknowledgedRecordCount: 2,
              remainingPendingCount: 0,
              confirmedAt: secondBatchTime,
            ),
            scheduleState: BackupScheduleState(
              schedule: BackupSchedule.daily,
              lastConfirmedAt: secondBatchTime,
              nextDueAt: DateTime.utc(2026, 11, 24, 10, 6),
            ),
          ),
        ),
      );
      expect(cloudPublisher.distinctServerCommits, 2);
      expect(cloudPublisher.cloudTransactions['tx-1']!.amountPiasters, 15000);
      expect(cloudPublisher.cloudAuditLogs.length, 1);
      expect(localStore.countPendingChanges(), 0);
    });

    test('inactive device rejection marks device inactive, preserves confirmed time, and blocks subsequent runs', () async {
      final previousConfirmed = DateTime.utc(2026, 11, 22, 10);
      localStore.scheduleState = BackupScheduleState(
        schedule: BackupSchedule.daily,
        lastConfirmedAt: previousConfirmed,
        nextDueAt: DateTime.utc(2026, 11, 23, 10),
      );
      localStore.putCustomer(testCustomer());
      cloudPublisher.rejectAsInactiveDevice = true;

      final rejected = await runBackup(trigger: BackupTrigger.manual);
      expect(
        rejected,
        Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.inactiveDevice,
            scheduleState: localStore.scheduleState,
          ),
        ),
      );
      expect(localStore.markDeviceInactiveCalls, 1);
      expect(localStore.isActiveDevice, isFalse);
      expect(localStore.acknowledgeCalls, 0);
      expect(localStore.scheduleState.lastConfirmedAt, previousConfirmed);

      final followUp = await runBackup(trigger: BackupTrigger.manual);
      expect(
        followUp,
        Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.inactiveDevice,
            scheduleState: localStore.scheduleState,
          ),
        ),
      );
      expect(cloudPublisher.publishAttempts, 1);
    });

    test('storage failure when persisting device rejection surfaces to caller, skips acknowledgment and releases lease', () async {
      final previousConfirmed = DateTime.utc(2026, 11, 22, 10);
      localStore.scheduleState = BackupScheduleState(
        schedule: BackupSchedule.daily,
        lastConfirmedAt: previousConfirmed,
        nextDueAt: DateTime.utc(2026, 11, 23, 10),
      );
      localStore.putCustomer(testCustomer());
      cloudPublisher.rejectAsInactiveDevice = true;
      localStore.markDeviceInactiveFailure = const AppFailure(
        AppErrorCode.storage,
      );

      final result = await runBackup(trigger: BackupTrigger.manual);
      expect(
        result,
        const Left<AppFailure, BackupRunResult>(
          AppFailure(AppErrorCode.storage),
        ),
      );
      expect(localStore.markDeviceInactiveCalls, 1);
      expect(localStore.acknowledgeCalls, 0);
      expect(localStore.countPendingChanges(), 1);
      expect(localStore.scheduleState.lastConfirmedAt, previousConfirmed);
      expect(runLock.isLocked, isFalse);
      expect(runLock.releaseCount, 1);
    });

    test('sign-out during upload prevents acknowledgment and preserves confirmed time', () async {
      final previousConfirmed = DateTime.utc(2026, 11, 22, 10);
      localStore.scheduleState = BackupScheduleState(
        lastConfirmedAt: previousConfirmed,
      );
      localStore.putCustomer(testCustomer());

      cloudPublisher.onPublishStarted = (_) async {
        localStore.authenticatedUserId = null;
      };

      final result = await runBackup(trigger: BackupTrigger.manual);
      expect(
        result,
        Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.signedOut,
            scheduleState: localStore.scheduleState,
          ),
        ),
      );
      expect(localStore.acknowledgeCalls, 0);
      expect(localStore.scheduleState.lastConfirmedAt, previousConfirmed);
      expect(localStore.countPendingChanges(), 1);
    });

    test('sign-out after post-upload eligibility check but before acknowledgment commit preserves pending revisions and confirmed time', () async {
      final previousConfirmed = DateTime.utc(2026, 11, 22, 10);
      localStore.scheduleState = BackupScheduleState(
        lastConfirmedAt: previousConfirmed,
      );
      localStore.putCustomer(testCustomer());

      final ackReached = Completer<void>();
      final releaseAck = Completer<void>();
      localStore.beforeAcknowledgeCommit = () async {
        ackReached.complete();
        await releaseAck.future;
      };

      final runFuture = runBackup(trigger: BackupTrigger.manual);
      await ackReached.future;

      // Sign out after post-upload check while retaining linkedOwnerUserId.
      localStore.authenticatedUserId = null;
      expect(localStore.linkedOwnerUserId, 'user-a');

      releaseAck.complete();
      final result = await runFuture;

      expect(
        result,
        Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.signedOut,
            scheduleState: BackupScheduleState(
              lastConfirmedAt: previousConfirmed,
            ),
          ),
        ),
      );
      expect(localStore.countPendingChanges(), 1);
      expect(localStore.inFlightBatch?.batchId, 'batch-1');
      expect(localStore.scheduleState.lastConfirmedAt, previousConfirmed);
    });

    test('device authority revoked after post-upload eligibility check but before acknowledgment commit preserves pending revisions and confirmed time', () async {
      final previousConfirmed = DateTime.utc(2026, 11, 22, 10);
      localStore.scheduleState = BackupScheduleState(
        lastConfirmedAt: previousConfirmed,
      );
      localStore.putCustomer(testCustomer());

      final ackReached = Completer<void>();
      final releaseAck = Completer<void>();
      localStore.beforeAcknowledgeCommit = () async {
        ackReached.complete();
        await releaseAck.future;
      };

      final runFuture = runBackup(trigger: BackupTrigger.manual);
      await ackReached.future;

      localStore.isActiveDevice = false;

      releaseAck.complete();
      final result = await runFuture;

      expect(
        result,
        Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.inactiveDevice,
            scheduleState: BackupScheduleState(
              lastConfirmedAt: previousConfirmed,
            ),
          ),
        ),
      );
      expect(localStore.countPendingChanges(), 1);
      expect(localStore.inFlightBatch?.batchId, 'batch-1');
      expect(localStore.scheduleState.lastConfirmedAt, previousConfirmed);
    });

    test(
      'account switch during upload cannot acknowledge another account data',
      () async {
        final previousConfirmed = DateTime.utc(2026, 11, 22, 10);
        localStore.scheduleState = BackupScheduleState(
          lastConfirmedAt: previousConfirmed,
        );
        localStore.putCustomer(testCustomer());

        cloudPublisher.onPublishStarted = (_) async {
          localStore.authenticatedUserId = 'user-b';
        };

        final result = await runBackup(trigger: BackupTrigger.manual);
        expect(
          result,
          Right<AppFailure, BackupRunResult>(
            BackupRunSkipped(
              reason: BackupIneligibilityReason.accountMismatch,
              scheduleState: localStore.scheduleState,
            ),
          ),
        );
        expect(localStore.acknowledgeCalls, 0);
        expect(localStore.scheduleState.lastConfirmedAt, previousConfirmed);
      },
    );
  });

  group('Scheduling changes, concurrent interleavings and overdue retries', () {
    test('UpdateBackupScheduleUseCase selects, replaces and deduplicates schedules', () async {
      final first = await updateSchedule(BackupSchedule.daily);
      expect(
        first,
        Right<AppFailure, BackupScheduleState>(
          BackupScheduleState(
            schedule: BackupSchedule.daily,
            nextDueAt: DateTime.utc(2026, 11, 24, 10),
          ),
        ),
      );
      expect(localStore.scheduleWriteCount, 1);

      // Re-selecting same schedule does not write again.
      final same = await updateSchedule(BackupSchedule.daily);
      expect(same, first);
      expect(localStore.scheduleWriteCount, 1);

      // Replacing schedule leaves one active schedule.
      final replaced = await updateSchedule(BackupSchedule.monthly);
      expect(
        replaced,
        Right<AppFailure, BackupScheduleState>(
          BackupScheduleState(
            schedule: BackupSchedule.monthly,
            nextDueAt: DateTime.utc(2026, 12, 23, 10),
          ),
        ),
      );
      expect(localStore.scheduleWriteCount, 2);
    });

    test('confirmed manual backup restarts active schedule interval', () async {
      localStore.putCustomer(testCustomer());
      await updateSchedule(BackupSchedule.weekly);

      clock.current = DateTime.utc(2026, 11, 25, 12);
      cloudPublisher.serverTime = DateTime.utc(2026, 11, 25, 12, 0, 10);

      final manual = await runBackup(trigger: BackupTrigger.manual);
      expect(manual.isRight(), isTrue);
      expect(
        localStore.scheduleState,
        BackupScheduleState(
          schedule: BackupSchedule.weekly,
          lastConfirmedAt: DateTime.utc(2026, 11, 25, 12, 0, 10),
          nextDueAt: DateTime.utc(2026, 12, 2, 12, 0, 10),
        ),
      );
    });

    test('interleaving Monthly selection before paused confirmation commit preserves both Monthly and confirmed timestamp', () async {
      final priorConfirmed = DateTime.utc(2026, 11, 15, 10);
      localStore.scheduleState = BackupScheduleState(
        schedule: BackupSchedule.weekly,
        lastConfirmedAt: priorConfirmed,
        nextDueAt: DateTime.utc(2026, 11, 22, 10),
      );
      localStore.putCustomer(testCustomer());

      final confirmedAt = DateTime.utc(2026, 1, 31, 14);
      cloudPublisher.serverTime = confirmedAt;

      final ackPaused = Completer<void>();
      final releaseAck = Completer<void>();
      localStore.beforeAcknowledgeCommit = () async {
        ackPaused.complete();
        await releaseAck.future;
      };

      final runFuture = runBackup(trigger: BackupTrigger.manual);
      await ackPaused.future;

      // Monthly selection lands after upload read Weekly, before ack commits.
      final scheduleResult = await updateSchedule(BackupSchedule.monthly);
      expect(scheduleResult.isRight(), isTrue);

      releaseAck.complete();
      final runResult = await runFuture;
      expect(runResult.isRight(), isTrue);

      expect(
        localStore.scheduleState,
        BackupScheduleState(
          schedule: BackupSchedule.monthly,
          lastConfirmedAt: confirmedAt,
          nextDueAt: DateTime.utc(2026, 2, 28, 14),
        ),
      );
    });

    test('interleaving confirmation before paused Monthly selection preserves both Monthly and latest confirmed timestamp', () async {
      final priorConfirmed = DateTime.utc(2026, 11, 15, 10);
      localStore.scheduleState = BackupScheduleState(
        schedule: BackupSchedule.weekly,
        lastConfirmedAt: priorConfirmed,
        nextDueAt: DateTime.utc(2026, 11, 22, 10),
      );
      localStore.putCustomer(testCustomer());

      final confirmedAt = DateTime.utc(2026, 11, 23, 10, 0, 5);
      cloudPublisher.serverTime = confirmedAt;

      final schedulePaused = Completer<void>();
      final releaseSchedule = Completer<void>();
      localStore.beforeScheduleUpdateCommit = () async {
        schedulePaused.complete();
        await releaseSchedule.future;
      };

      // Start Monthly selection and pause before commit.
      final scheduleFuture = updateSchedule(BackupSchedule.monthly);
      await schedulePaused.future;

      // Confirmation commits first, advancing lastConfirmedAt to confirmedAt.
      final runResult = await runBackup(trigger: BackupTrigger.manual);
      expect(runResult.isRight(), isTrue);
      expect(localStore.scheduleState.lastConfirmedAt, confirmedAt);

      // Monthly selection resumes against latest state and must not roll back confirmedAt.
      releaseSchedule.complete();
      final scheduleResult = await scheduleFuture;
      expect(
        scheduleResult,
        Right<AppFailure, BackupScheduleState>(
          BackupScheduleState(
            schedule: BackupSchedule.monthly,
            lastConfirmedAt: confirmedAt,
            nextDueAt: DateTime.utc(2026, 12, 23, 10, 0, 5),
          ),
        ),
      );
      expect(localStore.scheduleState, scheduleResult.getRight().toNullable());
    });

    test('interleaving Monthly selection with paused overdue empty check preserves Monthly and due date in both orders', () async {
      final priorConfirmed = DateTime.utc(2026, 11, 10, 10);

      // Order A: Overdue empty check pauses before commit; Monthly lands first.
      localStore.scheduleState = BackupScheduleState(
        schedule: BackupSchedule.daily,
        lastConfirmedAt: priorConfirmed,
        nextDueAt: DateTime.utc(2026, 11, 11, 10),
      );
      var pauseNextUpdate = true;
      final emptyCheckPaused = Completer<void>();
      final releaseEmptyCheck = Completer<void>();
      localStore.beforeScheduleUpdateCommit = () async {
        if (pauseNextUpdate) {
          pauseNextUpdate = false;
          emptyCheckPaused.complete();
          await releaseEmptyCheck.future;
        }
      };

      final emptyRunFuture = runBackup(trigger: BackupTrigger.scheduled);
      await emptyCheckPaused.future;

      await updateSchedule(BackupSchedule.monthly);
      releaseEmptyCheck.complete();
      await emptyRunFuture;

      expect(
        localStore.scheduleState,
        BackupScheduleState(
          schedule: BackupSchedule.monthly,
          lastConfirmedAt: priorConfirmed,
          nextDueAt: DateTime.utc(2026, 12, 10, 10),
        ),
      );

      // Order B: Monthly selection pauses before commit; overdue empty check lands first.
      localStore.scheduleState = BackupScheduleState(
        schedule: BackupSchedule.daily,
        lastConfirmedAt: priorConfirmed,
        nextDueAt: DateTime.utc(2026, 11, 11, 10),
      );
      var pauseScheduleUpdate = true;
      final monthlyPaused = Completer<void>();
      final releaseMonthly = Completer<void>();
      localStore.beforeScheduleUpdateCommit = () async {
        if (pauseScheduleUpdate) {
          pauseScheduleUpdate = false;
          monthlyPaused.complete();
          await releaseMonthly.future;
        }
      };

      final monthlyFuture = updateSchedule(BackupSchedule.monthly);
      await monthlyPaused.future;

      await runBackup(trigger: BackupTrigger.scheduled);
      releaseMonthly.complete();
      await monthlyFuture;

      expect(
        localStore.scheduleState,
        BackupScheduleState(
          schedule: BackupSchedule.monthly,
          lastConfirmedAt: priorConfirmed,
          nextDueAt: DateTime.utc(2026, 12, 10, 10),
        ),
      );
    });

    test('overdue pending backup blocked offline retries on next eligible check/launch', () async {
      final previousConfirmed = DateTime.utc(2026, 11, 20, 10);
      localStore.scheduleState = BackupScheduleState(
        schedule: BackupSchedule.daily,
        lastConfirmedAt: previousConfirmed,
        nextDueAt: DateTime.utc(2026, 11, 21, 10),
      );
      localStore.putCustomer(testCustomer());
      localStore.hasConnectivity = false;

      final offline = await runBackup(trigger: BackupTrigger.scheduled);
      expect(
        offline,
        Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.offline,
            scheduleState: localStore.scheduleState,
          ),
        ),
      );
      expect(
        BackupSchedulePolicy.isOverdue(localStore.scheduleState, clock.current),
        isTrue,
      );
      expect(cloudPublisher.publishAttempts, 0);

      // Next launch with connectivity restored runs overdue backup and restarts interval.
      localStore.hasConnectivity = true;
      clock.current = DateTime.utc(2026, 11, 24, 9);
      cloudPublisher.serverTime = DateTime.utc(2026, 11, 24, 9, 0, 2);

      final retried = await runBackup(trigger: BackupTrigger.scheduled);
      expect(retried.isRight(), isTrue);
      expect(cloudPublisher.distinctServerCommits, 1);
      expect(
        localStore.scheduleState,
        BackupScheduleState(
          schedule: BackupSchedule.daily,
          lastConfirmedAt: DateTime.utc(2026, 11, 24, 9, 0, 2),
          nextDueAt: DateTime.utc(2026, 11, 25, 9, 0, 2),
        ),
      );
    });
  });
}
