import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/restore_entities.dart';

/// Authenticated cloud contract for reading a consistent confirmed ledger
/// snapshot and atomically transferring backup device authority.
abstract interface class RestoreCloudService {
  /// Reads the authenticated account's cumulative confirmed cloud ledger at one
  /// consistent server version.
  ///
  /// When [expectedVersion] is supplied, returns
  /// [RestoreCloudSnapshotVersionChanged] if the server's confirmed version no
  /// longer matches [expectedVersion].
  /// Distinguishes a missing backup ([RestoreCloudSnapshotMissing]) from a
  /// valid confirmed snapshot with zero rows ([RestoreCloudSnapshotFound] where
  /// `snapshot.preview.hasZeroRows` is `true`).
  Future<Either<AppFailure, RestoreCloudSnapshotReadResult>>
  readConfirmedSnapshot({String? expectedVersion});

  /// Atomically and idempotently transfers active backup device authority for
  /// the authenticated session to [targetDeviceId] (proving possession of this
  /// installation's local device secret), serialized with publication on the
  /// server and comparing [expectedVersion] and [expectedActiveDeviceId].
  Future<Either<AppFailure, RestoreAuthorityTransferResult>>
  transferBackupAuthority({
    required String requestId,
    required String targetDeviceId,
    required String expectedVersion,
    required String expectedActiveDeviceId,
  });

  /// Checks whether [requestId] was already committed on the server for the
  /// authenticated account and [targetDeviceId].
  Future<Either<AppFailure, RestoreAuthorityTransferred?>>
  findAuthorityTransfer({
    required String requestId,
    required String targetDeviceId,
  });
}
