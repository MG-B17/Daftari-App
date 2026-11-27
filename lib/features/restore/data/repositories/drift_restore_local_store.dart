import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/services/session_commit_gate/session_commit_gate.dart';
import '../../../auth/session/data/services/ledger_owner_storage.dart';
import '../../../auth/session/data/services/secure_gotrue_storage.dart';
import '../../../auth/session/data/services/supabase_auth_service.dart';
import '../../../auth/session/domain/entities/auth_session_event.dart';
import '../../../backup/data/models/backup_batch_codec.dart';
import '../../../backup/data/services/backup_device_storage.dart';
import '../../../backup/domain/entities/backup_batch.dart';
import '../../../backup/domain/policies/backup_schedule_policy.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/restore_entities.dart';
import '../../domain/policies/restore_snapshot_validator.dart';
import '../../domain/repositories/restore_local_store.dart';

final class _ResolvedRestoreSession {
  const _ResolvedRestoreSession({
    required this.authenticatedUserId,
    required this.isEmailVerified,
    required this.sessionInstanceId,
    required this.epoch,
    required this.persistedPresent,
  });

  final String? authenticatedUserId;
  final bool isEmailVerified;
  final String? sessionInstanceId;
  final int epoch;
  final bool persistedPresent;
}

/// Drift + local-storage implementation of [RestoreLocalStore].
///
/// Enforces pre-commit validation of snapshot format, ownership, unique IDs,
/// parent references and field constraints, then executes atomic replacement
/// of `customers`, `transactions`, `transaction_audit_logs`,
/// `backup_in_flight_batches`, and `backup_metadata` in a single Drift SQLite
/// transaction while keeping device credentials, PIN, and preferences local.
class DriftRestoreLocalStore implements RestoreLocalStore {
  DriftRestoreLocalStore({
    required this._backupDao,
    required this._authService,
    required this._ownerStorage,
    required this._deviceStorage,
    required this._errorHandler,
    SessionCommitGate? commitGate,
    this._hasPersistedSession,
    this._readPersistedSession,
    this._afterDeleteBeforeInsertHook,
    this._beforeEnterCommitHook,
    this._afterSqlCommitBeforeOwnerClaimHook,
  }) : _commitGate = commitGate ?? SessionCommitGate() {
    _ownerStorage.bindDurableOwnerCallbacks(
      readDurableOwnerId: _backupDao.readDurableOwnerId,
      claimDurableOwnerId: _backupDao.claimOrReadDurableOwnerId,
    );
  }

  final BackupDao _backupDao;
  final AuthService _authService;
  final LedgerOwnerStorage _ownerStorage;
  final BackupDeviceStorage _deviceStorage;
  final ErrorHandler _errorHandler;
  final SessionCommitGate _commitGate;
  final Future<bool> Function()? _hasPersistedSession;
  final Future<PersistedSessionSnapshot?> Function()? _readPersistedSession;
  final Future<void> Function()? _afterDeleteBeforeInsertHook;
  final Future<void> Function()? _beforeEnterCommitHook;
  final Future<void> Function()? _afterSqlCommitBeforeOwnerClaimHook;

  Future<_ResolvedRestoreSession> _resolveLiveSession() async {
    final epoch = await _commitGate.readEpoch();
    final user = await _authService.getCurrentUser();
    final readPersisted = _readPersistedSession;
    if (readPersisted != null) {
      final persisted = await readPersisted();
      if (persisted == null || user == null) {
        return _ResolvedRestoreSession(
          authenticatedUserId: null,
          isEmailVerified: false,
          sessionInstanceId: null,
          epoch: epoch,
          persistedPresent: persisted != null,
        );
      }
      final persistedUserId = persisted.userId;
      if (persistedUserId != null && persistedUserId != user.id) {
        return _ResolvedRestoreSession(
          authenticatedUserId: persistedUserId,
          isEmailVerified: persisted.isEmailVerified,
          sessionInstanceId: '$epoch:$persistedUserId',
          epoch: epoch,
          persistedPresent: true,
        );
      }
      final verified = user.emailVerified && persisted.isEmailVerified;
      return _ResolvedRestoreSession(
        authenticatedUserId: user.id,
        isEmailVerified: verified,
        sessionInstanceId: '$epoch:${user.id}',
        epoch: epoch,
        persistedPresent: true,
      );
    }

    final checkPersisted = _hasPersistedSession;
    if (checkPersisted != null && !await checkPersisted()) {
      return _ResolvedRestoreSession(
        authenticatedUserId: null,
        isEmailVerified: false,
        sessionInstanceId: null,
        epoch: epoch,
        persistedPresent: false,
      );
    }
    if (user == null) {
      return _ResolvedRestoreSession(
        authenticatedUserId: null,
        isEmailVerified: false,
        sessionInstanceId: null,
        epoch: epoch,
        persistedPresent: true,
      );
    }
    return _ResolvedRestoreSession(
      authenticatedUserId: user.id,
      isEmailVerified: user.emailVerified,
      sessionInstanceId: '$epoch:${user.id}',
      epoch: epoch,
      persistedPresent: true,
    );
  }

  static int? _tryExtractAuthorizedEpoch(String? authorizedSessionId) {
    if (authorizedSessionId == null || authorizedSessionId.isEmpty) {
      return null;
    }
    final colonIndex = authorizedSessionId.indexOf(':');
    if (colonIndex <= 0) return null;
    return int.tryParse(authorizedSessionId.substring(0, colonIndex));
  }

  static RestoreLocalLedgerSummary _summaryFromCounts({
    required RestoreLedgerCountsSnapshot counts,
    required String? linkedOwnerUserId,
    required String deviceId,
  }) => RestoreLocalLedgerSummary(
    linkedOwnerUserId: linkedOwnerUserId,
    deviceId: deviceId,
    isActiveDevice: counts.isDeviceActive,
    customerCount: counts.customerCount,
    deletedCustomerCount: counts.deletedCustomerCount,
    transactionCount: counts.transactionCount,
    deletedTransactionCount: counts.deletedTransactionCount,
    auditLogCount: counts.auditLogCount,
    pendingChangesCount: counts.pendingChangesCount,
    revisionStamp: counts.revisionStamp,
  );

  @override
  Future<Either<AppFailure, RestoreLocalLedgerSummary>>
  readLocalLedgerSummary() => _guard(() async {
    final linkedOwnerUserId = await _ownerStorage.readOwnerId();
    final deviceId = await _deviceStorage.getOrCreateDeviceId();
    final counts = await _backupDao.readRestoreLedgerCounts();
    return _summaryFromCounts(
      counts: counts,
      linkedOwnerUserId: linkedOwnerUserId,
      deviceId: deviceId,
    );
  });

  @override
  Future<Either<AppFailure, RestoreLocalInstallResult>>
  installConfirmedSnapshot({
    required CloudBackupSnapshot snapshot,
    required RestoreConsentToken consent,
    String? authorizedSessionId,
  }) => _guard(() async {
    if (!consent.isFullyPermitted) {
      throw const ValidationException();
    }

    // Validate format, ownership, version binding, unique IDs, parent
    // references, preview count consistency, and all supported field values
    // before opening the write transaction.
    RestoreSnapshotValidator.validate(
      snapshot,
      expectedOwnerUserId: consent.ownerUserId,
      expectedVersion: consent.version,
    );

    final confirmedAtUtc = snapshot.preview.confirmedAt.toUtc();
    final restoredCustomers = snapshot.customers
        .map(
          (c) => CustomersCompanion(
            id: Value(c.id),
            name: Value(c.name),
            phone: Value(c.phone),
            notes: Value(c.notes),
            createdAt: Value(c.createdAt.toUtc()),
            updatedAt: Value(c.updatedAt.toUtc()),
            deletedAt: Value(c.deletedAt?.toUtc()),
            localRevision: Value(c.localRevision),
            acknowledgedRevision: Value(c.localRevision),
            syncedAt: Value(confirmedAtUtc),
          ),
        )
        .toList(growable: false);

    final restoredTransactions = snapshot.transactions
        .map(
          (t) => TransactionsCompanion(
            id: Value(t.id),
            customerId: Value(t.customerId),
            type: Value(
              t.type == TransactionType.credit
                  ? TransactionTypes.credit
                  : TransactionTypes.payment,
            ),
            amountPiasters: Value(t.amountPiasters),
            note: Value(t.note),
            transactionDate: Value(t.transactionDate.toUtc()),
            createdAt: Value(t.createdAt.toUtc()),
            updatedAt: Value(t.updatedAt.toUtc()),
            deletedAt: Value(t.deletedAt?.toUtc()),
            localRevision: Value(t.localRevision),
            acknowledgedRevision: Value(t.localRevision),
            syncedAt: Value(confirmedAtUtc),
          ),
        )
        .toList(growable: false);

    final restoredAuditLogs = snapshot.auditLogs
        .map(
          (a) => TransactionAuditLogsCompanion(
            id: Value(a.id),
            transactionId: Value(a.transactionId),
            action: Value(
              a.action == BackupAuditAction.edit
                  ? TransactionAuditActions.edit
                  : TransactionAuditActions.delete,
            ),
            previousType: Value(
              a.previousType == TransactionType.credit
                  ? TransactionTypes.credit
                  : TransactionTypes.payment,
            ),
            previousAmountPiasters: Value(a.previousAmountPiasters),
            previousNote: Value(a.previousNote),
            previousTransactionDate: Value(a.previousTransactionDate.toUtc()),
            createdAt: Value(a.createdAt.toUtc()),
            localRevision: Value(a.localRevision),
            acknowledgedRevision: Value(a.localRevision),
            syncedAt: Value(confirmedAtUtc),
          ),
        )
        .toList(growable: false);

    RestoreLocalInstallResult? blockedOutcome;
    var requiresReplacementButUnconfirmed = false;
    var sessionInvalidatedDuringCommit = false;
    final authorizedEpoch = _tryExtractAuthorizedEpoch(authorizedSessionId);
    var capturedEpoch = authorizedEpoch ?? 0;
    String? verifiedLinkedOwnerId;
    String? verifiedDeviceId;
    String? verifiedSessionInstanceId;
    RestoreLedgerCountsSnapshot? latestObservedCounts;

    final authSubscription = _authService.watchAuthChanges().listen((event) {
      switch (event) {
        case AuthSessionSignedOut():
          sessionInvalidatedDuringCommit = true;
        case AuthSessionSignedIn(:final user):
        case AuthSessionPasswordRecovery(:final user):
          if (!user.emailVerified || user.id != consent.ownerUserId) {
            sessionInvalidatedDuringCommit = true;
          }
        case AuthSessionFailure():
          break;
      }
    });

    bool isLiveSessionValid({_ResolvedRestoreSession? resolvedSession}) {
      if (resolvedSession != null && !resolvedSession.persistedPresent) {
        return false;
      }
      final currentUser = _authService.currentUser;
      final authenticatedUserId = resolvedSession != null
          ? (currentUser == null ? null : resolvedSession.authenticatedUserId)
          : currentUser?.id;
      final isEmailVerified = resolvedSession != null
          ? ((currentUser?.emailVerified ?? false) &&
                resolvedSession.isEmailVerified)
          : (currentUser?.emailVerified ?? false);
      final currentSessionInstanceId = resolvedSession != null
          ? (currentUser == null ? null : resolvedSession.sessionInstanceId)
          : verifiedSessionInstanceId;

      if (authenticatedUserId == null ||
          authenticatedUserId != consent.ownerUserId ||
          !isEmailVerified) {
        return false;
      }
      if (authorizedSessionId != null &&
          authorizedSessionId.trim().isNotEmpty &&
          currentSessionInstanceId != authorizedSessionId) {
        return false;
      }
      if (resolvedSession != null && resolvedSession.epoch != capturedEpoch) {
        return false;
      }
      if (sessionInvalidatedDuringCommit || _commitGate.isInvalidating) {
        return false;
      }
      return true;
    }

    try {
      final outcome = await _backupDao.installConfirmedSnapshot(
        restoredCustomers: restoredCustomers,
        restoredTransactions: restoredTransactions,
        restoredAuditLogs: restoredAuditLogs,
        ownerUserId: consent.ownerUserId,
        afterDeleteBeforeInsertHook: _afterDeleteBeforeInsertHook,
        verifyInstallAllowed: (currentCounts, currentMetadata) async {
          latestObservedCounts = currentCounts;
          final linkedOwnerId = await _ownerStorage.readOwnerId();
          final deviceId = await _deviceStorage.getOrCreateDeviceId();
          final liveSession = await _resolveLiveSession();
          capturedEpoch = authorizedEpoch ?? liveSession.epoch;
          verifiedSessionInstanceId = liveSession.sessionInstanceId;
          verifiedLinkedOwnerId = linkedOwnerId;
          verifiedDeviceId = deviceId;

          final currentSummary = _summaryFromCounts(
            counts: currentCounts,
            linkedOwnerUserId: linkedOwnerId,
            deviceId: deviceId,
          );

          if (!isLiveSessionValid(resolvedSession: liveSession) ||
              deviceId != consent.localDeviceId) {
            blockedOutcome = RestoreLocalInstallBlockedSessionInvalidated(
              localLedger: currentSummary,
            );
            return false;
          }

          if (currentSummary.isAccountMismatchFor(consent.ownerUserId)) {
            blockedOutcome = RestoreLocalInstallBlockedAccountMismatch(
              localLedger: currentSummary,
            );
            return false;
          }

          final isAlreadyInstalled =
              currentMetadata.lastConfirmedAtIso ==
                  confirmedAtUtc.toIso8601String() &&
              BackupDao.matchesInstalledCompanions(
                currentCounts: currentCounts,
                restoredCustomers: restoredCustomers,
                restoredTransactions: restoredTransactions,
                restoredAuditLogs: restoredAuditLogs,
              );

          if (!isAlreadyInstalled &&
              currentSummary.revisionStamp != consent.localRevisionStamp) {
            blockedOutcome = RestoreLocalInstallBlockedLocalLedgerChanged(
              updatedLocalLedger: currentSummary,
            );
            return false;
          }

          if (!isAlreadyInstalled &&
              currentSummary.isPopulated &&
              !consent.replacementConfirmed) {
            requiresReplacementButUnconfirmed = true;
            return false;
          }

          return true;
        },
        verifyBeforeCommit: () {
          if (!isLiveSessionValid()) {
            blockedOutcome = RestoreLocalInstallBlockedSessionInvalidated(
              localLedger: _summaryFromCounts(
                counts: latestObservedCounts!,
                linkedOwnerUserId: verifiedLinkedOwnerId,
                deviceId: verifiedDeviceId ?? consent.localDeviceId,
              ),
            );
            return false;
          }
          return true;
        },
        tryEnterCommit: () async {
          final hook = _beforeEnterCommitHook;
          if (hook != null) {
            await hook();
          }
          final liveSession = await _resolveLiveSession();
          if (!isLiveSessionValid(resolvedSession: liveSession)) {
            blockedOutcome = RestoreLocalInstallBlockedSessionInvalidated(
              localLedger: _summaryFromCounts(
                counts: latestObservedCounts!,
                linkedOwnerUserId: verifiedLinkedOwnerId,
                deviceId: verifiedDeviceId ?? consent.localDeviceId,
              ),
            );
            return false;
          }
          final entered = await _commitGate.tryEnterCommit(
            expectedEpoch: capturedEpoch,
          );
          if (!entered) {
            blockedOutcome = RestoreLocalInstallBlockedSessionInvalidated(
              localLedger: _summaryFromCounts(
                counts: latestObservedCounts!,
                linkedOwnerUserId: verifiedLinkedOwnerId,
                deviceId: verifiedDeviceId ?? consent.localDeviceId,
              ),
            );
            return false;
          }
          return true;
        },
        onExitCommitAsync: _commitGate.exitCommit,
        updateMetadata: (latest) {
          final currentSchedule = BackupBatchCodec.scheduleStateFromMetadata(
            latest,
          );
          final nextSchedule = BackupSchedulePolicy.recordConfirmation(
            currentSchedule,
            confirmedAt: confirmedAtUtc,
          );
          return BackupBatchCodec.metadataFromScheduleState(
            nextSchedule,
            isDeviceActive: true,
          );
        },
      );

      if (requiresReplacementButUnconfirmed) {
        throw const ValidationException();
      }

      if (outcome == null) {
        return blockedOutcome!;
      }

      if (_afterSqlCommitBeforeOwnerClaimHook case final afterSqlHook?) {
        await afterSqlHook();
      }

      final claimed = await _ownerStorage.claimOwnerId(consent.ownerUserId);
      if (claimed != consent.ownerUserId) {
        throw const AuthException();
      }

      return RestoreLocalInstallApplied(
        localLedger: _summaryFromCounts(
          counts: outcome.counts,
          linkedOwnerUserId: consent.ownerUserId,
          deviceId: verifiedDeviceId ?? consent.localDeviceId,
        ),
        scheduleState: BackupBatchCodec.scheduleStateFromMetadata(
          outcome.metadata,
        ),
      );
    } finally {
      await authSubscription.cancel();
    }
  });

  Future<Either<AppFailure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } catch (error) {
      return Left(await _errorHandler.handle(error));
    }
  }
}
