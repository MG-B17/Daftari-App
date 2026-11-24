import 'package:fpdart/fpdart.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/session_commit_gate.dart';
import '../../../auth/session/data/services/ledger_owner_storage.dart';
import '../../../auth/session/data/services/secure_gotrue_storage.dart';
import '../../../auth/session/data/services/supabase_auth_service.dart';
import '../../../auth/session/domain/entities/auth_session_event.dart';
import '../../domain/entities/backup_batch.dart';
import '../../domain/entities/backup_eligibility.dart';
import '../../domain/entities/backup_schedule.dart';
import '../../domain/policies/backup_cutoff_policy.dart';
import '../../domain/repositories/backup_local_store.dart';
import '../models/backup_batch_codec.dart';
import '../services/backup_device_storage.dart';

final class _ResolvedLiveSession {
  const _ResolvedLiveSession({
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

/// Drift + local-storage implementation of [BackupLocalStore].
///
/// Guarantees SQLite-transactional batch cutoff capture, durable in-flight
/// batch recovery, atomic schedule transitions, and commit-time session/device
/// verification (including pre-commit rollback on mid-transaction sign-out,
/// session-replacement rejection across isolates, and cross-isolate commit-gate
/// serialization against foreground sign-out).
class DriftBackupLocalStore implements BackupLocalStore {
  DriftBackupLocalStore({
    required this._backupDao,
    required this._authService,
    required this._ownerStorage,
    required this._deviceStorage,
    required this._connectivityService,
    required this._errorHandler,
    SessionCommitGate? commitGate,
    this._isBackupRunning,
    this._hasPersistedSession,
    this._readPersistedSession,
    this._beforeEnterCommitHook,
  }) : _commitGate = commitGate ?? SessionCommitGate();

  final BackupDao _backupDao;
  final AuthService _authService;
  final LedgerOwnerStorage _ownerStorage;
  final BackupDeviceStorage _deviceStorage;
  final ConnectivityService _connectivityService;
  final ErrorHandler _errorHandler;
  final SessionCommitGate _commitGate;
  final bool Function()? _isBackupRunning;
  final Future<bool> Function()? _hasPersistedSession;
  final Future<PersistedSessionSnapshot?> Function()? _readPersistedSession;
  final Future<void> Function()? _beforeEnterCommitHook;

  Future<_ResolvedLiveSession> _resolveLiveSession() async {
    final epoch = await _commitGate.readEpoch();
    final user = await _authService.getCurrentUser();
    final readPersisted = _readPersistedSession;
    if (readPersisted != null) {
      final persisted = await readPersisted();
      if (persisted == null || user == null) {
        return _ResolvedLiveSession(
          authenticatedUserId: null,
          isEmailVerified: false,
          sessionInstanceId: null,
          epoch: epoch,
          persistedPresent: persisted != null,
        );
      }
      final persistedUserId = persisted.userId;
      if (persistedUserId != null && persistedUserId != user.id) {
        return _ResolvedLiveSession(
          authenticatedUserId: persistedUserId,
          isEmailVerified: persisted.isEmailVerified,
          sessionInstanceId: '$epoch:$persistedUserId',
          epoch: epoch,
          persistedPresent: true,
        );
      }
      final verified = user.emailVerified && persisted.isEmailVerified;
      return _ResolvedLiveSession(
        authenticatedUserId: user.id,
        isEmailVerified: verified,
        sessionInstanceId: '$epoch:${user.id}',
        epoch: epoch,
        persistedPresent: true,
      );
    }

    final checkPersisted = _hasPersistedSession;
    if (checkPersisted != null && !await checkPersisted()) {
      return _ResolvedLiveSession(
        authenticatedUserId: null,
        isEmailVerified: false,
        sessionInstanceId: null,
        epoch: epoch,
        persistedPresent: false,
      );
    }
    if (user == null) {
      return _ResolvedLiveSession(
        authenticatedUserId: null,
        isEmailVerified: false,
        sessionInstanceId: null,
        epoch: epoch,
        persistedPresent: true,
      );
    }
    return _ResolvedLiveSession(
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

  @override
  Future<Either<AppFailure, BackupEligibilityContext>>
  readEligibilityContext() => _guard(() async {
    final liveSession = await _resolveLiveSession();
    final linkedOwnerUserId = await _ownerStorage.readOwnerId();
    final deviceId = await _deviceStorage.getOrCreateDeviceId();
    final localStatus = await _backupDao.readLocalStatus();
    final hasConnectivity = await _connectivityService.isConnected;
    return BackupEligibilityContext(
      authenticatedUserId: liveSession.authenticatedUserId,
      isEmailVerified: liveSession.isEmailVerified,
      linkedOwnerUserId: linkedOwnerUserId,
      deviceId: deviceId,
      isActiveDevice: localStatus.isDeviceActive,
      pendingChangesCount: localStatus.pendingChangesCount,
      hasConnectivity: hasConnectivity,
      isBackupRunning: _isBackupRunning?.call() ?? false,
      sessionInstanceId: liveSession.sessionInstanceId,
    );
  });

  @override
  Future<Either<AppFailure, BackupScheduleState>> readScheduleState() =>
      _guard(() async {
        final metadata = await _backupDao.readMetadata();
        return BackupBatchCodec.scheduleStateFromMetadata(metadata);
      });

  @override
  Future<Either<AppFailure, BackupScheduleState>> updateScheduleState(
    BackupScheduleState Function(
      BackupScheduleState latest,
      bool hasPendingChanges,
    )
    transform,
  ) => _guard(() async {
    final updated = await _backupDao.updateScheduleMetadata((
      latest,
      hasPendingChanges,
    ) {
      final currentSchedule = BackupBatchCodec.scheduleStateFromMetadata(
        latest,
      );
      final nextSchedule = transform(currentSchedule, hasPendingChanges);
      return BackupBatchCodec.metadataFromScheduleState(
        nextSchedule,
        isDeviceActive: latest.isDeviceActive,
      );
    });
    return BackupBatchCodec.scheduleStateFromMetadata(updated);
  });

  @override
  Future<Either<AppFailure, BackupBatch?>> readInFlightBatch() =>
      _guard(() async {
        final row = await _backupDao.readInFlightBatch();
        if (row == null) return null;
        return BackupBatchCodec.decodeInFlightRow(row);
      });

  @override
  Future<Either<AppFailure, BackupBatch>> capturePendingBatch({
    required String batchId,
    required String ownerUserId,
    required String deviceId,
    required DateTime capturedAt,
  }) => _guard(() async {
    final trimmedBatchId = batchId.trim();
    final trimmedOwnerId = ownerUserId.trim();
    final trimmedDeviceId = deviceId.trim();
    if (trimmedBatchId.isEmpty ||
        trimmedOwnerId.isEmpty ||
        trimmedDeviceId.isEmpty) {
      throw const ValidationException();
    }

    final capturedAtUtc = capturedAt.toUtc();
    late List<BackupCustomerRecord> customers;
    late List<BackupTransactionRecord> transactions;
    late List<BackupAuditLogRecord> auditLogs;

    final snapshot = await _backupDao.capturePendingBatch(
      batchId: trimmedBatchId,
      ownerUserId: trimmedOwnerId,
      deviceId: trimmedDeviceId,
      capturedAtIso: capturedAtUtc.toIso8601String(),
      encodePayload: (pending) {
        customers = pending.customers
            .map(BackupBatchCodec.customerFromRow)
            .toList(growable: false);
        transactions = pending.transactions
            .map(BackupBatchCodec.transactionFromRow)
            .toList(growable: false);
        auditLogs = pending.auditLogs
            .map(BackupBatchCodec.auditLogFromRow)
            .toList(growable: false);
        return BackupBatchCodec.encodeRecordsPayload(
          customers: customers,
          transactions: transactions,
          auditLogs: auditLogs,
        );
      },
    );

    if (snapshot.isEmpty) {
      return BackupBatch(
        batchId: trimmedBatchId,
        ownerUserId: trimmedOwnerId,
        deviceId: trimmedDeviceId,
        capturedAt: capturedAtUtc,
        customers: const [],
        transactions: const [],
        auditLogs: const [],
      );
    }

    return BackupBatch(
      batchId: trimmedBatchId,
      ownerUserId: trimmedOwnerId,
      deviceId: trimmedDeviceId,
      capturedAt: capturedAtUtc,
      customers: customers,
      transactions: transactions,
      auditLogs: auditLogs,
    );
  });

  @override
  Future<Either<AppFailure, BackupAcknowledgmentResult>> acknowledgeBatch(
    BackupBatchAcknowledgment acknowledgment, {
    required BackupScheduleState Function(BackupScheduleState latest)
    updateSchedule,
  }) => _guard(() async {
    BackupIneligibilityReason? blockedReason;
    BackupScheduleState? blockedSchedule;
    String? verifiedLinkedOwnerId;
    String? verifiedDeviceId;
    var verifiedIsDeviceActive = false;
    var sessionInvalidatedDuringCommit = false;
    final authorizedSessionId = acknowledgment.authorizedSessionId;
    final authorizedEpoch = _tryExtractAuthorizedEpoch(authorizedSessionId);
    var capturedEpoch = authorizedEpoch ?? 0;
    String? verifiedSessionInstanceId;

    final authSubscription = _authService.watchAuthChanges().listen((event) {
      switch (event) {
        case AuthSessionSignedOut():
          sessionInvalidatedDuringCommit = true;
        case AuthSessionSignedIn(:final user):
        case AuthSessionPasswordRecovery(:final user):
          if (!user.emailVerified || user.id != acknowledgment.ownerUserId) {
            sessionInvalidatedDuringCommit = true;
          }
        case AuthSessionFailure():
          break;
      }
    });

    BackupIneligibilityReason? evaluateCurrentAuthority({
      required String? linkedOwnerUserId,
      required String? deviceId,
      required bool isDeviceActive,
      _ResolvedLiveSession? resolvedSession,
    }) {
      if (resolvedSession != null && !resolvedSession.persistedPresent) {
        return BackupIneligibilityReason.signedOut;
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

      final liveReason = BackupCutoffPolicy.acknowledgmentBlockReason(
        batchOwnerUserId: acknowledgment.ownerUserId,
        batchDeviceId: acknowledgment.deviceId,
        authorizedSessionId: authorizedSessionId,
        currentContext: BackupEligibilityContext(
          authenticatedUserId: authenticatedUserId,
          isEmailVerified: isEmailVerified,
          linkedOwnerUserId: linkedOwnerUserId,
          deviceId: deviceId,
          isActiveDevice: isDeviceActive,
          pendingChangesCount: 0,
          hasConnectivity: true,
          sessionInstanceId: currentSessionInstanceId,
        ),
      );
      if (liveReason != null) return liveReason;
      if (resolvedSession != null && resolvedSession.epoch != capturedEpoch) {
        return BackupIneligibilityReason.signedOut;
      }
      if (sessionInvalidatedDuringCommit || _commitGate.isInvalidating) {
        return BackupIneligibilityReason.signedOut;
      }
      return null;
    }

    try {
      final outcome = await _backupDao.acknowledgeBatch(
        batchId: acknowledgment.batchId,
        confirmedAt: acknowledgment.confirmedAt,
        customerRevisions: acknowledgment.customerRevisions,
        transactionRevisions: acknowledgment.transactionRevisions,
        auditLogRevisions: acknowledgment.auditLogRevisions,
        verifyCommitAllowed: (latest) async {
          final linkedOwnerUserId = await _ownerStorage.readOwnerId();
          final deviceId = await _deviceStorage.readDeviceId();
          final liveSession = await _resolveLiveSession();
          capturedEpoch = authorizedEpoch ?? liveSession.epoch;
          verifiedSessionInstanceId = liveSession.sessionInstanceId;
          verifiedLinkedOwnerId = linkedOwnerUserId;
          verifiedDeviceId = deviceId;
          verifiedIsDeviceActive = latest.isDeviceActive;
          blockedSchedule = BackupBatchCodec.scheduleStateFromMetadata(latest);

          final reason = evaluateCurrentAuthority(
            linkedOwnerUserId: linkedOwnerUserId,
            deviceId: deviceId,
            isDeviceActive: latest.isDeviceActive,
            resolvedSession: liveSession,
          );
          if (reason != null) {
            blockedReason = reason;
            return false;
          }
          return true;
        },
        verifyBeforeCommit: () {
          final reason = evaluateCurrentAuthority(
            linkedOwnerUserId: verifiedLinkedOwnerId,
            deviceId: verifiedDeviceId,
            isDeviceActive: verifiedIsDeviceActive,
          );
          if (reason != null) {
            blockedReason = reason;
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
          final reason = evaluateCurrentAuthority(
            linkedOwnerUserId: verifiedLinkedOwnerId,
            deviceId: verifiedDeviceId,
            isDeviceActive: verifiedIsDeviceActive,
            resolvedSession: liveSession,
          );
          if (reason != null) {
            blockedReason = reason;
            return false;
          }
          final entered = await _commitGate.tryEnterCommit(
            expectedEpoch: capturedEpoch,
          );
          if (!entered) {
            blockedReason ??= BackupIneligibilityReason.signedOut;
            return false;
          }
          return true;
        },
        onExitCommitAsync: _commitGate.exitCommit,
        updateSchedule: (latest) {
          final currentSchedule = BackupBatchCodec.scheduleStateFromMetadata(
            latest,
          );
          final nextSchedule = updateSchedule(currentSchedule);
          return BackupBatchCodec.metadataFromScheduleState(
            nextSchedule,
            isDeviceActive: latest.isDeviceActive,
          );
        },
        resolveRevision: BackupCutoffPolicy.resolveAcknowledgedRevision,
      );

      if (outcome == null) {
        return BackupAcknowledgmentBlocked(
          reason: blockedReason!,
          scheduleState: blockedSchedule!,
        );
      }

      return BackupAcknowledgmentApplied(
        summary: BackupAcknowledgmentSummary(
          acknowledgedRecordCount: outcome.acknowledgedRecordCount,
          remainingPendingCount: outcome.remainingPendingCount,
          confirmedAt: acknowledgment.confirmedAt,
        ),
        scheduleState: BackupBatchCodec.scheduleStateFromMetadata(
          outcome.metadata,
        ),
      );
    } finally {
      await authSubscription.cancel();
    }
  });

  @override
  Future<Either<AppFailure, void>> markDeviceInactive() =>
      _guard(_backupDao.markDeviceInactive);

  Future<Either<AppFailure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } catch (error) {
      return Left(await _errorHandler.handle(error));
    }
  }
}
