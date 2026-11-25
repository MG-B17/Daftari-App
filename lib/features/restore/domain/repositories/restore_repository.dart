import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/restore_entities.dart';

/// Domain contract for inspecting confirmed cloud backups, enforcing bound
/// user consent, coordinating device authority transfer, and recovering
/// interrupted transfers.
abstract interface class RestoreRepository {
  /// Inspects the current session, local ledger ownership and record counts,
  /// any persisted interrupted transfer, and the latest confirmed cloud
  /// snapshot metadata.
  Future<Either<AppFailure, RestoreInspectionResult>> inspectRestore();

  /// Validates and installs the confirmed cloud backup bound to [consent],
  /// transferring active backup device authority when [consent.requiresTakeover]
  /// is `true`.
  ///
  /// Rejects execution if [consent.isFullyPermitted] is `false`, if local
  /// ownership conflicts, or if either the local ledger revision or the
  /// confirmed cloud version/active device changed since preview.
  Future<Either<AppFailure, RestoreExecutionResult>> executeRestore({
    required RestoreConsentToken consent,
  });

  /// Recovers and completes a previously persisted [pendingTransfer] using the
  /// same idempotent request ID and bound version.
  Future<Either<AppFailure, RestoreExecutionResult>> resumePendingTransfer(
    PendingRestoreTransfer pendingTransfer,
  );

  /// Discards a pre-commit [pendingTransfer] when cancelled before server
  /// takeover has committed.
  Future<Either<AppFailure, void>> discardPendingTransfer(String requestId);
}
