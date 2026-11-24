import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/date_service.dart';
import '../entities/backup_batch.dart';
import '../entities/backup_eligibility.dart';
import '../entities/backup_run_result.dart';
import '../entities/backup_schedule.dart';
import '../policies/backup_cutoff_policy.dart';
import '../policies/backup_eligibility_policy.dart';
import '../policies/backup_schedule_policy.dart';
import '../repositories/backup_cloud_publisher.dart';
import '../repositories/backup_local_store.dart';
import '../repositories/backup_run_lock.dart';

/// Orchestrates manual and scheduled cloud backups through one shared
/// single-flight, eligibility, cutoff-capture, publication recovery and
/// conditional revision-checked acknowledgment pipeline.
class RunBackupUseCase {
  RunBackupUseCase({
    required this._localStore,
    required this._cloudPublisher,
    required this._runLock,
    required this._dateService,
    String Function()? generateBatchId,
  }) : _generateBatchId = generateBatchId ?? _defaultBatchId;

  static const _uuid = Uuid();
  static String _defaultBatchId() => _uuid.v4();

  final BackupLocalStore _localStore;
  final BackupCloudPublisher _cloudPublisher;
  final BackupRunLock _runLock;
  final DateService _dateService;
  final String Function() _generateBatchId;

  Future<Either<AppFailure, BackupRunResult>> call({
    required BackupTrigger trigger,
  }) async {
    final lease = await _runLock.tryAcquire();
    if (lease == null) {
      return const Right(
        BackupRunSkipped(reason: BackupIneligibilityReason.alreadyRunning),
      );
    }

    try {
      return await _runLocked(trigger);
    } finally {
      await lease.release();
    }
  }

  Future<Either<AppFailure, BackupRunResult>> _runLocked(
    BackupTrigger trigger,
  ) async {
    final now = _dateService.now().toUtc();

    final BackupScheduleState scheduleState;
    switch (await _localStore.readScheduleState()) {
      case Left(:final value):
        return Left(value);
      case Right(:final value):
        scheduleState = value;
    }

    final BackupEligibilityContext context;
    switch (await _localStore.readEligibilityContext()) {
      case Left(:final value):
        return Left(value);
      case Right(:final value):
        // This run already holds the exclusive lease, so clear isBackupRunning
        // in case the store derives it from BackupRunLock.isLocked.
        context = value.copyWith(isBackupRunning: false);
    }

    final decision = BackupEligibilityPolicy.evaluate(
      trigger: trigger,
      context: context,
      scheduleState: scheduleState,
      now: now,
    );
    if (!decision.isEligible) {
      return _handleSkipped(
        trigger: trigger,
        reason: decision.reason!,
        scheduleState: scheduleState,
        now: now,
      );
    }

    final ownerUserId = context.linkedOwnerUserId!;
    final deviceId = context.deviceId!;
    final authorizedSessionId = context.sessionInstanceId;

    final BackupBatch? inFlightBatch;
    switch (await _localStore.readInFlightBatch()) {
      case Left(:final value):
        return Left(value);
      case Right(:final value):
        inFlightBatch = value;
    }

    final BackupBatch batch;
    BackupPublicationResult? publication;

    if (inFlightBatch != null) {
      if (inFlightBatch.ownerUserId != ownerUserId) {
        return const Left(AppFailure(AppErrorCode.auth));
      }
      if (inFlightBatch.deviceId != deviceId) {
        return Right(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.inactiveDevice,
            scheduleState: scheduleState,
          ),
        );
      }
      batch = inFlightBatch;
      switch (await _cloudPublisher.findBatchConfirmation(
        batchId: batch.batchId,
        ownerUserId: batch.ownerUserId,
        deviceId: batch.deviceId,
      )) {
        case Left(:final value):
          return Left(value);
        case Right(:final value):
          publication = value;
      }
    } else {
      final batchId = _generateBatchId();
      switch (await _localStore.capturePendingBatch(
        batchId: batchId,
        ownerUserId: ownerUserId,
        deviceId: deviceId,
        capturedAt: now,
      )) {
        case Left(:final value):
          return Left(value);
        case Right(:final value):
          batch = value;
      }

      if (batch.isEmpty) {
        return _handleSkipped(
          trigger: trigger,
          reason: BackupIneligibilityReason.noPendingChanges,
          scheduleState: scheduleState,
          now: now,
        );
      }
      if (batch.batchId != batchId ||
          batch.ownerUserId != ownerUserId ||
          batch.deviceId != deviceId) {
        return const Left(AppFailure(AppErrorCode.unexpected));
      }
    }

    if (publication == null) {
      switch (await _cloudPublisher.publishBatch(batch)) {
        case Left(:final value):
          return Left(value);
        case Right(:final value):
          publication = value;
      }
    }

    switch (publication) {
      case BackupPublicationInactiveDevice():
        switch (await _localStore.markDeviceInactive()) {
          case Left(:final value):
            return Left(value);
          case Right():
            return Right(
              BackupRunSkipped(
                reason: BackupIneligibilityReason.inactiveDevice,
                scheduleState: scheduleState,
              ),
            );
        }
      case BackupPublicationConfirmed(
        batchId: final confirmedBatchId,
        confirmedAt: final confirmedAt,
      ):
        if (confirmedBatchId != batch.batchId) {
          return const Left(AppFailure(AppErrorCode.unexpected));
        }

        // Fast-path session check after upload; the store also enforces the
        // same check atomically at commit time so sign-out or device revocation
        // right before acknowledgment can never commit stale revisions.
        final BackupEligibilityContext postUploadContext;
        switch (await _localStore.readEligibilityContext()) {
          case Left(:final value):
            return Left(value);
          case Right(:final value):
            postUploadContext = value;
        }

        final blockReason = BackupCutoffPolicy.acknowledgmentBlockReason(
          batchOwnerUserId: batch.ownerUserId,
          batchDeviceId: batch.deviceId,
          currentContext: postUploadContext,
          authorizedSessionId: authorizedSessionId,
        );
        if (blockReason != null) {
          return Right(
            BackupRunSkipped(reason: blockReason, scheduleState: scheduleState),
          );
        }

        final acknowledgment = batch.toAcknowledgment(
          confirmedAt: confirmedAt,
          authorizedSessionId: authorizedSessionId,
        );
        final ackResult = await _localStore.acknowledgeBatch(
          acknowledgment,
          updateSchedule: (latest) => BackupSchedulePolicy.recordConfirmation(
            latest,
            confirmedAt: confirmedAt,
          ),
        );
        return ackResult.fold(Left.new, (result) {
          return switch (result) {
            BackupAcknowledgmentBlocked(:final reason, :final scheduleState) =>
              Right(
                BackupRunSkipped(reason: reason, scheduleState: scheduleState),
              ),
            BackupAcknowledgmentApplied(:final summary, :final scheduleState) =>
              Right(
                BackupRunConfirmed(
                  batchId: batch.batchId,
                  summary: summary,
                  scheduleState: scheduleState,
                ),
              ),
          };
        });
    }
  }

  Future<Either<AppFailure, BackupRunResult>> _handleSkipped({
    required BackupTrigger trigger,
    required BackupIneligibilityReason reason,
    required BackupScheduleState scheduleState,
    required DateTime now,
  }) async {
    if (trigger == BackupTrigger.scheduled &&
        reason == BackupIneligibilityReason.noPendingChanges) {
      final updateResult = await _localStore.updateScheduleState(
        (latest, hasPendingChanges) => hasPendingChanges
            ? latest
            : BackupSchedulePolicy.recordSkippedNoChanges(latest, now: now),
      );
      return updateResult.fold(
        Left.new,
        (saved) =>
            Right(BackupRunSkipped(reason: reason, scheduleState: saved)),
      );
    }
    return Right(
      BackupRunSkipped(reason: reason, scheduleState: scheduleState),
    );
  }
}
