import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/backup_batch.dart';
import '../entities/backup_run_result.dart';

/// Remote publication contract implemented over Supabase in Task 3.
abstract interface class BackupCloudPublisher {
  /// Checks whether [batchId] was already committed server-side for
  /// [ownerUserId] and [deviceId].
  ///
  /// Returns [BackupPublicationConfirmed] with the original server confirmation
  /// timestamp if already committed, [BackupPublicationInactiveDevice] if
  /// another device now owns backup authority, or `null` if [batchId] has not
  /// been committed.
  Future<Either<AppFailure, BackupPublicationResult?>> findBatchConfirmation({
    required String batchId,
    required String ownerUserId,
    required String deviceId,
  });

  /// Atomically and idempotently publishes [batch] for [batch.ownerUserId]
  /// from [batch.deviceId] keyed by [batch.batchId].
  ///
  /// Returns [BackupPublicationConfirmed] only after the entire batch is
  /// committed server-side, or [BackupPublicationInactiveDevice] when another
  /// device holds backup authority for the account.
  Future<Either<AppFailure, BackupPublicationResult>> publishBatch(
    BackupBatch batch,
  );
}
