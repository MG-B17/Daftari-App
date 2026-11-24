import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/backup_batch.dart';
import '../entities/backup_eligibility.dart';
import '../entities/backup_schedule.dart';

/// Local ledger and backup-metadata contract implemented over Drift and local
/// persistence in Task 3.
abstract interface class BackupLocalStore {
  Future<Either<AppFailure, BackupEligibilityContext>> readEligibilityContext();

  Future<Either<AppFailure, BackupScheduleState>> readScheduleState();

  /// Atomically applies [transform] to the latest persisted
  /// [BackupScheduleState] and current pending-changes state so concurrent
  /// schedule selections, confirmations and overdue empty checks never undo
  /// each other.
  Future<Either<AppFailure, BackupScheduleState>> updateScheduleState(
    BackupScheduleState Function(
      BackupScheduleState latest,
      bool hasPendingChanges,
    )
    transform,
  );

  /// Reads an unacknowledged in-flight batch persisted before a previous
  /// publication attempt, or `null` if none exists.
  Future<Either<AppFailure, BackupBatch?>> readInFlightBatch();

  /// Atomically captures pending customers, transactions (including tombstones)
  /// and append-only audit logs together with their current local revisions,
  /// and persists the batch as the durable in-flight batch when non-empty.
  ///
  /// Returns an empty [BackupBatch] without saving an in-flight batch when
  /// there are no pending changes.
  Future<Either<AppFailure, BackupBatch>> capturePendingBatch({
    required String batchId,
    required String ownerUserId,
    required String deviceId,
    required DateTime capturedAt,
  });

  /// Atomically verifies at commit time that the live authenticated verified
  /// session, linked owner and active device authority still match
  /// [acknowledgment] (`BackupCutoffPolicy.acknowledgmentBlockReason`).
  ///
  /// When blocked, returns [BackupAcknowledgmentBlocked] without mutating local
  /// revisions, the in-flight batch, or schedule metadata. Otherwise
  /// acknowledges only the captured revisions, clears the matching in-flight
  /// batch, and applies [updateSchedule] to the latest persisted
  /// [BackupScheduleState].
  Future<Either<AppFailure, BackupAcknowledgmentResult>> acknowledgeBatch(
    BackupBatchAcknowledgment acknowledgment, {
    required BackupScheduleState Function(BackupScheduleState latest)
    updateSchedule,
  });

  /// Persists that this device is cloud-inactive after server rejection.
  Future<Either<AppFailure, void>> markDeviceInactive();
}
