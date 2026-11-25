import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../backup/domain/entities/backup_schedule.dart';
import '../entities/restore_entities.dart';

/// Atomic outcome of attempting to install a validated [CloudBackupSnapshot]
/// into the local Drift database.
sealed class RestoreLocalInstallResult extends Equatable {
  const RestoreLocalInstallResult();

  @override
  List<Object?> get props => [];
}

final class RestoreLocalInstallApplied extends RestoreLocalInstallResult {
  const RestoreLocalInstallApplied({
    required this.localLedger,
    required this.scheduleState,
  });

  final RestoreLocalLedgerSummary localLedger;
  final BackupScheduleState scheduleState;

  @override
  List<Object?> get props => [localLedger, scheduleState];
}

final class RestoreLocalInstallBlockedAccountMismatch
    extends RestoreLocalInstallResult {
  const RestoreLocalInstallBlockedAccountMismatch({required this.localLedger});

  final RestoreLocalLedgerSummary localLedger;

  @override
  List<Object?> get props => [localLedger];
}

final class RestoreLocalInstallBlockedLocalLedgerChanged
    extends RestoreLocalInstallResult {
  const RestoreLocalInstallBlockedLocalLedgerChanged({
    required this.updatedLocalLedger,
  });

  final RestoreLocalLedgerSummary updatedLocalLedger;

  @override
  List<Object?> get props => [updatedLocalLedger];
}

final class RestoreLocalInstallBlockedSessionInvalidated
    extends RestoreLocalInstallResult {
  const RestoreLocalInstallBlockedSessionInvalidated({
    required this.localLedger,
  });

  final RestoreLocalLedgerSummary localLedger;

  @override
  List<Object?> get props => [localLedger];
}

/// Local storage and atomic Drift installation contract for Phase 13 restore.
abstract interface class RestoreLocalStore {
  /// Reads a consistent summary of the current local ledger, including active
  /// and soft-deleted counts, audit history count, pending changes count, and
  /// a revision stamp that changes on any local mutation.
  Future<Either<AppFailure, RestoreLocalLedgerSummary>>
  readLocalLedgerSummary();

  /// Atomically validates [snapshot] and [consent], re-verifies live session
  /// ownership and local ledger revision stamp inside a single Drift SQLite
  /// transaction, replaces all ledger tables (`customers`, `transactions`,
  /// `transaction_audit_logs`), marks all restored rows as already acknowledged,
  /// clears any superseded in-flight backup batch, and updates local backup
  /// metadata (`isDeviceActive: true`, `lastConfirmedAt: snapshot.preview.confirmedAt`).
  ///
  /// Device credentials, PIN, and app preferences remain device-local and
  /// untouched.
  Future<Either<AppFailure, RestoreLocalInstallResult>>
  installConfirmedSnapshot({
    required CloudBackupSnapshot snapshot,
    required RestoreConsentToken consent,
    String? authorizedSessionId,
  });
}
