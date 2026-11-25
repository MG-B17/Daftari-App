import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/date_service.dart';
import '../../../auth/session/data/services/secure_gotrue_storage.dart';
import '../../../auth/session/data/services/supabase_auth_service.dart';
import '../../../auth/session/presentation/cubit/auth_session_state.dart';
import '../../../backup/domain/repositories/backup_run_lock.dart';
import '../../../backup/domain/repositories/backup_scheduler.dart';
import '../../domain/entities/restore_entities.dart';
import '../../domain/policies/restore_snapshot_validator.dart';
import '../../domain/repositories/restore_cloud_service.dart';
import '../../domain/repositories/restore_local_store.dart';
import '../../domain/repositories/restore_repository.dart';
import '../services/restore_transfer_storage.dart';

/// Signal thrown by test interruption hooks to simulate process interruption or
/// network drop at a deterministic stage (before takeover, after server commit,
/// or after local SQLite commit).
class RestoreStageInterruption implements Exception {
  const RestoreStageInterruption(this.stage);

  final RestoreTransferStage stage;
}

/// Real [RestoreRepository] implementation coordinating confirmed cloud
/// snapshot download, pre-takeover validation and staging, idempotent server
/// authority transfer, atomic Drift installation, restart recovery, and mutual
/// exclusion with manual and scheduled backup workers.
class RestoreRepositoryImpl implements RestoreRepository {
  RestoreRepositoryImpl({
    required this._localStore,
    required this._cloudService,
    required this._transferStorage,
    required this._runLock,
    required this._scheduler,
    required this._authService,
    required this._connectivityService,
    required this._dateService,
    required this._errorHandler,
    this._readAuthState,
    this._hasPersistedSession,
    this._readPersistedSession,
    this._notifyExternalStateChanged,
    String Function()? generateRequestId,
    this.beforeExecuteHook,
    this.beforeTakeoverHook,
    this.afterTakeoverBeforeLocalInstallHook,
    this.afterLocalCommitBeforeClearHook,
  }) : _generateRequestId = generateRequestId ?? _defaultRequestId;

  static const _uuid = Uuid();
  static String _defaultRequestId() => _uuid.v4();

  final RestoreLocalStore _localStore;
  final RestoreCloudService _cloudService;
  final RestoreTransferStorage _transferStorage;
  final BackupRunLock _runLock;
  final BackupScheduler _scheduler;
  final AuthService _authService;
  final ConnectivityService _connectivityService;
  final DateService _dateService;
  final ErrorHandler _errorHandler;
  final AuthSessionState Function()? _readAuthState;
  final Future<bool> Function()? _hasPersistedSession;
  final Future<PersistedSessionSnapshot?> Function()? _readPersistedSession;
  final Future<void> Function()? _notifyExternalStateChanged;
  final String Function() _generateRequestId;

  /// Optional deterministic hooks used by integration tests to inject edits,
  /// account changes, or stage interruptions.
  Future<void> Function()? beforeExecuteHook;
  Future<void> Function(PendingRestoreTransfer transfer)? beforeTakeoverHook;
  Future<void> Function(PendingRestoreTransfer transfer)?
  afterTakeoverBeforeLocalInstallHook;
  Future<void> Function(PendingRestoreTransfer transfer)?
  afterLocalCommitBeforeClearHook;

  Future<Either<AppFailure, RestoreExecutionResult>>? _activeExecution;
  String? _activeExecutionKey;
  Future<void> _operationQueue = Future<void>.value();

  Future<T> _serializeOperation<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<RestoreAccountInfo?> _resolveAccount() async {
    final authState = _readAuthState?.call();
    if (authState != null &&
        authState.status == AuthStatus.emailVerificationRequired) {
      final email = authState.pendingEmail ?? authState.user?.email ?? '';
      return RestoreAccountInfo(
        userId: authState.user?.id ?? '',
        email: email,
        shopName: authState.user?.shopName,
        isEmailVerified: false,
      );
    }

    final user = await _authService.getCurrentUser();
    final readPersisted = _readPersistedSession;
    if (readPersisted != null) {
      final persisted = await readPersisted();
      if (persisted == null || user == null) {
        return null;
      }
      final persistedUserId = persisted.userId;
      if (persistedUserId != null && persistedUserId != user.id) {
        return null;
      }
      return RestoreAccountInfo(
        userId: user.id,
        email: user.email,
        shopName: user.shopName,
        isEmailVerified: user.emailVerified && persisted.isEmailVerified,
      );
    }

    final checkPersisted = _hasPersistedSession;
    if (checkPersisted != null && !await checkPersisted()) {
      return null;
    }

    if (user == null) {
      if (authState != null && authState.isAuthenticated) {
        final stateUser = authState.user;
        if (stateUser != null) {
          return RestoreAccountInfo(
            userId: stateUser.id,
            email: stateUser.email,
            shopName: stateUser.shopName,
            isEmailVerified: stateUser.emailVerified,
          );
        }
      }
      return null;
    }

    return RestoreAccountInfo(
      userId: user.id,
      email: user.email,
      shopName: user.shopName,
      isEmailVerified: user.emailVerified,
    );
  }

  @override
  Future<Either<AppFailure, RestoreInspectionResult>> inspectRestore() async {
    try {
      final account = await _resolveAccount();
      if (account == null) {
        return const Right(RestoreInspectionSignedOut());
      }
      if (!account.isEmailVerified) {
        return Right(
          RestoreInspectionEmailUnverified(
            email: account.email,
            shopName: account.shopName,
          ),
        );
      }

      final RestoreLocalLedgerSummary localLedger;
      switch (await _localStore.readLocalLedgerSummary()) {
        case Left(:final value):
          return Left(value);
        case Right(:final value):
          localLedger = value;
      }

      if (localLedger.isAccountMismatchFor(account.userId)) {
        return Right(
          RestoreInspectionAccountMismatch(
            account: account,
            localLedger: localLedger,
          ),
        );
      }

      final persisted = await _transferStorage.readPendingTransfer();
      final isOnline = await _connectivityService.isConnected;

      if (persisted != null &&
          persisted.transfer.ownerUserId == account.userId) {
        var transfer = persisted.transfer;
        if (!isOnline) {
          return Right(
            RestoreInspectionOffline(
              account: account,
              localLedger: localLedger,
              pendingTransfer: transfer,
            ),
          );
        }

        // If the previous attempt was interrupted while requesting takeover
        // (e.g. response lost after server commit), reconcile with the server.
        // If the lookup fails, preserve isTakeoverOutcomeUnknown=true so
        // Cancel stays disabled while the server outcome is unknown (P13-01).
        if (transfer.requiresTakeover &&
            transfer.stage == RestoreTransferStage.takeoverPending) {
          final lookup = await _cloudService.findAuthorityTransfer(
            requestId: transfer.requestId,
            targetDeviceId: localLedger.deviceId,
          );
          switch (lookup) {
            case Right(value: final found?):
              final updatedPreview = transfer.cloudPreview.copyWith(
                activeDeviceId: found.activeDeviceId,
                confirmedAt: found.confirmedAt,
              );
              final updatedPayload = await _transferStorage.updateStage(
                requestId: transfer.requestId,
                stage: RestoreTransferStage.takeoverConfirmed,
                cloudPreview: updatedPreview,
                isTakeoverOutcomeUnknown: false,
              );
              if (updatedPayload != null) {
                transfer = updatedPayload.transfer;
              }
            case Left():
              final updatedPayload = await _transferStorage.updateStage(
                requestId: transfer.requestId,
                isTakeoverOutcomeUnknown: true,
              );
              if (updatedPayload != null) {
                transfer = updatedPayload.transfer;
              }
            case Right(value: null):
              break;
          }
        }

        return Right(
          RestoreInspectionInterruptedTransfer(
            account: account,
            localLedger: localLedger,
            pendingTransfer: transfer,
          ),
        );
      }

      if (!isOnline) {
        return Right(
          RestoreInspectionOffline(account: account, localLedger: localLedger),
        );
      }

      switch (await _cloudService.readConfirmedSnapshot()) {
        case Left(:final value):
          if (value.errorCode == AppErrorCode.network) {
            return Right(
              RestoreInspectionOffline(
                account: account,
                localLedger: localLedger,
              ),
            );
          }
          return Left(value);
        case Right(value: RestoreCloudSnapshotMissing()):
          return Right(
            RestoreInspectionMissingBackup(
              account: account,
              localLedger: localLedger,
            ),
          );
        case Right(value: RestoreCloudSnapshotVersionChanged(:final preview)):
          return Right(
            RestoreInspectionReady(
              account: account,
              localLedger: localLedger,
              cloudPreview: preview,
            ),
          );
        case Right(value: RestoreCloudSnapshotFound(:final snapshot)):
          return Right(
            RestoreInspectionReady(
              account: account,
              localLedger: localLedger,
              cloudPreview: snapshot.preview,
            ),
          );
      }
    } catch (error) {
      return Left(await _errorHandler.handle(error));
    }
  }

  @override
  Future<Either<AppFailure, RestoreExecutionResult>> executeRestore({
    required RestoreConsentToken consent,
  }) {
    if (!consent.isFullyPermitted) {
      return Future.value(const Left(AppFailure(AppErrorCode.validation)));
    }
    final key = 'execute:${consent.version}:${consent.localRevisionStamp}';
    if (_activeExecution != null && _activeExecutionKey == key) {
      return _activeExecution!;
    }
    final future = _serializeOperation(
      () => _runWithExclusiveLock(() => _executeRestoreLocked(consent)),
    );
    _activeExecution = future;
    _activeExecutionKey = key;
    return future.whenComplete(() {
      if (identical(_activeExecution, future)) {
        _activeExecution = null;
        _activeExecutionKey = null;
      }
    });
  }

  @override
  Future<Either<AppFailure, RestoreExecutionResult>> resumePendingTransfer(
    PendingRestoreTransfer pendingTransfer,
  ) {
    final key = 'resume:${pendingTransfer.requestId}';
    if (_activeExecution != null && _activeExecutionKey == key) {
      return _activeExecution!;
    }
    final future = _serializeOperation(
      () => _runWithExclusiveLock(
        () => _resumePendingTransferLocked(pendingTransfer),
      ),
    );
    _activeExecution = future;
    _activeExecutionKey = key;
    return future.whenComplete(() {
      if (identical(_activeExecution, future)) {
        _activeExecution = null;
        _activeExecutionKey = null;
      }
    });
  }

  @override
  Future<Either<AppFailure, void>> discardPendingTransfer(String requestId) =>
      _serializeOperation(
        () => _runWithExclusiveLockVoid(
          () => _discardPendingTransferLocked(requestId),
        ),
      );

  Future<Either<AppFailure, void>> _discardPendingTransferLocked(
    String requestId,
  ) async {
    final current = await _transferStorage.readPendingTransfer();
    if (current == null || current.transfer.requestId != requestId) {
      return const Right(null);
    }

    final transfer = current.transfer;
    if (transfer.stage != RestoreTransferStage.takeoverPending) {
      return const Left(AppFailure(AppErrorCode.validation));
    }

    // If a takeover request was already sent to the server, its outcome may be
    // committed even though the local stage is still takeoverPending (P13-01).
    // Never delete the staged transfer or clear the upload block while the
    // server outcome is unknown or already committed.
    if (transfer.requiresTakeover && transfer.isTakeoverOutcomeUnknown) {
      if (!await _connectivityService.isConnected) {
        return const Left(AppFailure(AppErrorCode.network));
      }
      final lookup = await _cloudService.findAuthorityTransfer(
        requestId: transfer.requestId,
        targetDeviceId: transfer.targetDeviceId,
      );
      switch (lookup) {
        case Left(:final value):
          return Left(value);
        case Right(value: final found?):
          final updatedPreview = transfer.cloudPreview.copyWith(
            activeDeviceId: found.activeDeviceId,
            confirmedAt: found.confirmedAt,
          );
          await _transferStorage.updateStage(
            requestId: transfer.requestId,
            stage: RestoreTransferStage.takeoverConfirmed,
            cloudPreview: updatedPreview,
            isTakeoverOutcomeUnknown: false,
          );
          return const Left(AppFailure(AppErrorCode.validation));
        case Right(value: null):
          break;
      }
    }

    await _transferStorage.clearPendingTransfer(requestId: requestId);
    await _notifyExternalStateChanged?.call();
    return const Right(null);
  }

  Future<Either<AppFailure, RestoreExecutionResult>> _runWithExclusiveLock(
    Future<Either<AppFailure, RestoreExecutionResult>> Function() action,
  ) async {
    BackupRunLease? lease;
    for (var attempt = 0; attempt < 20; attempt++) {
      lease = await _runLock.tryAcquire();
      if (lease != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    if (lease == null) {
      return const Left(AppFailure(AppErrorCode.unexpected));
    }
    try {
      return await action();
    } catch (error) {
      return Left(await _errorHandler.handle(error));
    } finally {
      await lease.release();
    }
  }

  Future<Either<AppFailure, void>> _runWithExclusiveLockVoid(
    Future<Either<AppFailure, void>> Function() action,
  ) async {
    BackupRunLease? lease;
    for (var attempt = 0; attempt < 20; attempt++) {
      lease = await _runLock.tryAcquire();
      if (lease != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    if (lease == null) {
      return const Left(AppFailure(AppErrorCode.unexpected));
    }
    try {
      return await action();
    } catch (error) {
      return Left(await _errorHandler.handle(error));
    } finally {
      await lease.release();
    }
  }

  Future<Either<AppFailure, RestoreExecutionResult>> _executeRestoreLocked(
    RestoreConsentToken consent,
  ) async {
    if (beforeExecuteHook case final hook?) {
      await hook();
    }

    final account = await _resolveAccount();
    if (account == null ||
        !account.isEmailVerified ||
        account.userId != consent.ownerUserId) {
      return const Left(AppFailure(AppErrorCode.auth));
    }

    final RestoreLocalLedgerSummary localLedger;
    switch (await _localStore.readLocalLedgerSummary()) {
      case Left(:final value):
        return Left(value);
      case Right(:final value):
        localLedger = value;
    }

    if (localLedger.isAccountMismatchFor(account.userId)) {
      return Right(
        RestoreExecutionBlockedAccountMismatch(
          account: account,
          localLedger: localLedger,
        ),
      );
    }

    if (localLedger.revisionStamp != consent.localRevisionStamp ||
        localLedger.deviceId != consent.localDeviceId) {
      final preview = await _readPreviewOrFallbackFromConsent(consent);
      return Right(
        RestoreExecutionLocalLedgerChanged(
          account: account,
          updatedLocalLedger: localLedger,
          cloudPreview: preview,
        ),
      );
    }

    if (localLedger.isPopulated && !consent.replacementConfirmed) {
      return const Left(AppFailure(AppErrorCode.validation));
    }

    // If a persisted transfer already exists for this owner, device, and
    // expected version (for example, when reconfirming replacement consent
    // after a local edit occurred post-takeover in P13-02), update its
    // consented local revision stamp and drive that existing request to
    // completion without losing the committed takeover or upload block.
    final existingPersisted = await _transferStorage.readPendingTransfer();
    if (existingPersisted != null &&
        existingPersisted.transfer.ownerUserId == account.userId &&
        existingPersisted.transfer.targetDeviceId == localLedger.deviceId &&
        existingPersisted.transfer.expectedVersion == consent.version &&
        (existingPersisted.transfer.stage !=
                RestoreTransferStage.takeoverPending ||
            existingPersisted.transfer.isTakeoverOutcomeUnknown)) {
      final updatedPayload = await _transferStorage.updateStage(
        requestId: existingPersisted.transfer.requestId,
        consentedLocalRevisionStamp: consent.localRevisionStamp,
        requiresReplacement: localLedger.isPopulated,
      );
      final resumedTransfer =
          updatedPayload?.transfer ??
          existingPersisted.transfer.copyWith(
            consentedLocalRevisionStamp: consent.localRevisionStamp,
            requiresReplacement: localLedger.isPopulated,
          );
      final resumedSnapshot =
          updatedPayload?.stagedSnapshot ?? existingPersisted.stagedSnapshot;
      return _driveStagedTransfer(
        account: account,
        currentLedger: localLedger,
        transfer: resumedTransfer,
        stagedSnapshot: resumedSnapshot,
        isInitialExecution: false,
      );
    }

    if (!await _connectivityService.isConnected) {
      return Right(
        RestoreExecutionOffline(account: account, localLedger: localLedger),
      );
    }

    final CloudBackupSnapshot snapshot;
    switch (await _cloudService.readConfirmedSnapshot(
      expectedVersion: consent.version,
    )) {
      case Left(:final value):
        if (value.errorCode == AppErrorCode.network) {
          return Right(
            RestoreExecutionOffline(account: account, localLedger: localLedger),
          );
        }
        return Left(value);
      case Right(value: RestoreCloudSnapshotMissing()):
        return const Left(AppFailure(AppErrorCode.validation));
      case Right(value: RestoreCloudSnapshotVersionChanged(:final preview)):
        return Right(
          RestoreExecutionCloudVersionChanged(
            account: account,
            localLedger: localLedger,
            updatedCloudPreview: preview,
          ),
        );
      case Right(value: RestoreCloudSnapshotFound(snapshot: final found)):
        snapshot = found;
    }

    if (snapshot.preview.version != consent.version ||
        snapshot.preview.activeDeviceId != consent.activeDeviceId) {
      return Right(
        RestoreExecutionCloudVersionChanged(
          account: account,
          localLedger: localLedger,
          updatedCloudPreview: snapshot.preview,
        ),
      );
    }

    final requiresTakeover =
        localLedger.deviceId != snapshot.preview.activeDeviceId;
    if (requiresTakeover != consent.requiresTakeover) {
      return Right(
        RestoreExecutionCloudVersionChanged(
          account: account,
          localLedger: localLedger,
          updatedCloudPreview: snapshot.preview,
        ),
      );
    }

    // Validate format, ownership, unique IDs, parent references, and field
    // constraints before staging or requesting server takeover.
    try {
      RestoreSnapshotValidator.validate(
        snapshot,
        expectedOwnerUserId: account.userId,
        expectedVersion: consent.version,
      );
    } on ValidationException {
      return const Left(AppFailure(AppErrorCode.validation));
    }

    // Recheck session, ownership, and local ledger revision right after
    // download/validation and before persisting transfer progress.
    final postDownloadAccount = await _resolveAccount();
    if (postDownloadAccount == null ||
        !postDownloadAccount.isEmailVerified ||
        postDownloadAccount.userId != consent.ownerUserId) {
      return const Left(AppFailure(AppErrorCode.auth));
    }

    final RestoreLocalLedgerSummary postDownloadLedger;
    switch (await _localStore.readLocalLedgerSummary()) {
      case Left(:final value):
        return Left(value);
      case Right(:final value):
        postDownloadLedger = value;
    }

    if (postDownloadLedger.isAccountMismatchFor(account.userId)) {
      return Right(
        RestoreExecutionBlockedAccountMismatch(
          account: account,
          localLedger: postDownloadLedger,
        ),
      );
    }

    if (postDownloadLedger.revisionStamp != consent.localRevisionStamp ||
        postDownloadLedger.deviceId != consent.localDeviceId) {
      return Right(
        RestoreExecutionLocalLedgerChanged(
          account: account,
          updatedLocalLedger: postDownloadLedger,
          cloudPreview: snapshot.preview,
        ),
      );
    }

    // Persist durable transfer progress and staged snapshot BEFORE requesting
    // server takeover so interruption at any subsequent point can recover.
    final initialStage = requiresTakeover
        ? RestoreTransferStage.takeoverPending
        : RestoreTransferStage.installingLocally;
    final pendingTransfer = PendingRestoreTransfer(
      requestId: _generateRequestId(),
      ownerUserId: account.userId,
      targetDeviceId: postDownloadLedger.deviceId,
      expectedVersion: snapshot.preview.version,
      expectedActiveDeviceId: snapshot.preview.activeDeviceId,
      confirmedAt: snapshot.preview.confirmedAt,
      requiresTakeover: requiresTakeover,
      requiresReplacement: postDownloadLedger.isPopulated,
      consentedLocalRevisionStamp: consent.localRevisionStamp,
      stage: initialStage,
      cloudPreview: snapshot.preview,
      isTakeoverOutcomeUnknown: false,
    );

    await _transferStorage.writePendingTransfer(
      transfer: pendingTransfer,
      stagedSnapshot: snapshot,
    );
    await _notifyExternalStateChanged?.call();

    return _driveStagedTransfer(
      account: account,
      currentLedger: postDownloadLedger,
      transfer: pendingTransfer,
      stagedSnapshot: snapshot,
      isInitialExecution: true,
    );
  }

  Future<Either<AppFailure, RestoreExecutionResult>>
  _resumePendingTransferLocked(PendingRestoreTransfer requestedTransfer) async {
    final account = await _resolveAccount();
    if (account == null ||
        !account.isEmailVerified ||
        account.userId != requestedTransfer.ownerUserId) {
      return const Left(AppFailure(AppErrorCode.auth));
    }

    final RestoreLocalLedgerSummary localLedger;
    switch (await _localStore.readLocalLedgerSummary()) {
      case Left(:final value):
        return Left(value);
      case Right(:final value):
        localLedger = value;
    }

    if (localLedger.isAccountMismatchFor(account.userId)) {
      return Right(
        RestoreExecutionBlockedAccountMismatch(
          account: account,
          localLedger: localLedger,
        ),
      );
    }

    // Require the durable persisted request ID to match the requested transfer
    // so a stale Resume action can never revive a cancelled request or hijack a
    // newer request's staged snapshot (P13-04).
    final persisted = await _transferStorage.readPendingTransfer();
    if (persisted == null ||
        persisted.transfer.requestId != requestedTransfer.requestId) {
      return const Left(AppFailure(AppErrorCode.validation));
    }

    final transfer = persisted.transfer;
    final stagedSnapshot = persisted.stagedSnapshot;

    if (!await _connectivityService.isConnected) {
      return Right(
        RestoreExecutionOffline(
          account: account,
          localLedger: localLedger,
          pendingTransfer: transfer,
        ),
      );
    }

    return _driveStagedTransfer(
      account: account,
      currentLedger: localLedger,
      transfer: transfer,
      stagedSnapshot: stagedSnapshot,
      isInitialExecution: false,
    );
  }

  Future<Either<AppFailure, RestoreExecutionResult>> _driveStagedTransfer({
    required RestoreAccountInfo account,
    required RestoreLocalLedgerSummary currentLedger,
    required PendingRestoreTransfer transfer,
    required CloudBackupSnapshot stagedSnapshot,
    required bool isInitialExecution,
  }) async {
    var activeTransfer = transfer;
    var activeSnapshot = stagedSnapshot;

    // 1. Coordinate server takeover when restoring onto a new phone.
    if (activeTransfer.requiresTakeover) {
      if (beforeTakeoverHook != null &&
          activeTransfer.stage == RestoreTransferStage.takeoverPending &&
          !activeTransfer.isTakeoverOutcomeUnknown) {
        try {
          await beforeTakeoverHook!(activeTransfer);
        } on RestoreStageInterruption {
          return Right(
            RestoreExecutionInterrupted(
              account: account,
              localLedger: currentLedger,
              pendingTransfer: activeTransfer,
            ),
          );
        }
      }

      // If a takeover request was previously dispatched and its response was
      // lost, reconcile its server outcome FIRST before deciding whether a
      // local edit can discard the transfer or must preserve the upload block
      // (P13-01, P13-02).
      if (activeTransfer.stage == RestoreTransferStage.takeoverPending &&
          (!isInitialExecution || activeTransfer.isTakeoverOutcomeUnknown)) {
        switch (await _cloudService.findAuthorityTransfer(
          requestId: activeTransfer.requestId,
          targetDeviceId: activeTransfer.targetDeviceId,
        )) {
          case Left(:final value):
            final unknownTransfer = activeTransfer.copyWith(
              isTakeoverOutcomeUnknown: true,
            );
            await _transferStorage.writePendingTransfer(
              transfer: unknownTransfer,
              stagedSnapshot: activeSnapshot,
            );
            return _handleTransferFailure(
              value,
              account: account,
              localLedger: currentLedger,
              transfer: unknownTransfer,
            );
          case Right(value: final found?):
            final nextPreview = activeSnapshot.preview.copyWith(
              activeDeviceId: found.activeDeviceId,
              confirmedAt: found.confirmedAt,
            );
            activeTransfer = activeTransfer.copyWith(
              stage: RestoreTransferStage.takeoverConfirmed,
              cloudPreview: nextPreview,
              isTakeoverOutcomeUnknown: false,
            );
            activeSnapshot = CloudBackupSnapshot(
              preview: nextPreview,
              customers: activeSnapshot.customers,
              transactions: activeSnapshot.transactions,
              auditLogs: activeSnapshot.auditLogs,
            );
            await _transferStorage.writePendingTransfer(
              transfer: activeTransfer,
              stagedSnapshot: activeSnapshot,
            );
          case Right(value: null):
            if (activeTransfer.isTakeoverOutcomeUnknown) {
              activeTransfer = activeTransfer.copyWith(
                isTakeoverOutcomeUnknown: false,
              );
              await _transferStorage.writePendingTransfer(
                transfer: activeTransfer,
                stagedSnapshot: activeSnapshot,
              );
            }
        }
      }

      // When takeover is still pending, check local ledger ownership and
      // revision stamp before dispatching a new takeover request to the server.
      // (Once takeover is confirmed or installingLocally, _localStore enforces
      // the atomic revision and idempotent-already-installed check inside the
      // SQLite transaction.)
      if (activeTransfer.stage == RestoreTransferStage.takeoverPending) {
        switch (await _localStore.readLocalLedgerSummary()) {
          case Left(:final value):
            return Left(value);
          case Right(value: final latestLedger):
            if (latestLedger.isAccountMismatchFor(account.userId)) {
              if (!activeTransfer.isTakeoverOutcomeUnknown) {
                await _transferStorage.clearPendingTransfer(
                  requestId: activeTransfer.requestId,
                );
                await _notifyExternalStateChanged?.call();
              }
              return Right(
                RestoreExecutionBlockedAccountMismatch(
                  account: account,
                  localLedger: latestLedger,
                ),
              );
            }
            if (latestLedger.revisionStamp !=
                activeTransfer.consentedLocalRevisionStamp) {
              if (!activeTransfer.isTakeoverOutcomeUnknown) {
                await _transferStorage.clearPendingTransfer(
                  requestId: activeTransfer.requestId,
                );
                await _notifyExternalStateChanged?.call();
              }
              return Right(
                RestoreExecutionLocalLedgerChanged(
                  account: account,
                  updatedLocalLedger: latestLedger,
                  cloudPreview: activeSnapshot.preview,
                ),
              );
            }
        }
      }

      if (activeTransfer.stage == RestoreTransferStage.takeoverPending) {
        // Mark the takeover outcome as unknown immediately before dispatching
        // the RPC so a lost response or mid-request crash disables Cancel until
        // the server outcome is reconciled (P13-01).
        activeTransfer = activeTransfer.copyWith(
          isTakeoverOutcomeUnknown: true,
        );
        await _transferStorage.writePendingTransfer(
          transfer: activeTransfer,
          stagedSnapshot: activeSnapshot,
        );

        switch (await _cloudService.transferBackupAuthority(
          requestId: activeTransfer.requestId,
          targetDeviceId: activeTransfer.targetDeviceId,
          expectedVersion: activeTransfer.expectedVersion,
          expectedActiveDeviceId: activeTransfer.expectedActiveDeviceId,
        )) {
          case Left(:final value):
            return _handleTransferFailure(
              value,
              account: account,
              localLedger: currentLedger,
              transfer: activeTransfer,
            );
          case Right(value: RestoreAuthorityMissingBackup()):
            await _transferStorage.clearPendingTransfer(
              requestId: activeTransfer.requestId,
            );
            await _notifyExternalStateChanged?.call();
            return const Left(AppFailure(AppErrorCode.validation));
          case Right(
            value: RestoreAuthorityPreconditionFailed(
              :final currentVersion,
              :final activeDeviceId,
              :final confirmedAt,
            ),
          ):
            await _transferStorage.clearPendingTransfer(
              requestId: activeTransfer.requestId,
            );
            await _notifyExternalStateChanged?.call();
            final updatedPreview = await _readLatestCloudPreview(
              fallback: activeSnapshot.preview.copyWith(
                version: currentVersion,
                activeDeviceId: activeDeviceId,
                confirmedAt: confirmedAt,
              ),
            );
            return Right(
              RestoreExecutionCloudVersionChanged(
                account: account,
                localLedger: currentLedger,
                updatedCloudPreview: updatedPreview,
              ),
            );
          case Right(
            value: RestoreAuthorityTransferred(
              :final activeDeviceId,
              :final confirmedAt,
            ),
          ):
            final nextPreview = activeSnapshot.preview.copyWith(
              activeDeviceId: activeDeviceId,
              confirmedAt: confirmedAt,
            );
            activeTransfer = activeTransfer.copyWith(
              stage: RestoreTransferStage.takeoverConfirmed,
              cloudPreview: nextPreview,
              isTakeoverOutcomeUnknown: false,
            );
            activeSnapshot = CloudBackupSnapshot(
              preview: nextPreview,
              customers: activeSnapshot.customers,
              transactions: activeSnapshot.transactions,
              auditLogs: activeSnapshot.auditLogs,
            );
            await _transferStorage.writePendingTransfer(
              transfer: activeTransfer,
              stagedSnapshot: activeSnapshot,
            );
        }
      }

      if (afterTakeoverBeforeLocalInstallHook != null) {
        try {
          await afterTakeoverBeforeLocalInstallHook!(activeTransfer);
        } on RestoreStageInterruption {
          return Right(
            RestoreExecutionInterrupted(
              account: account,
              localLedger: currentLedger,
              pendingTransfer: activeTransfer,
            ),
          );
        }
      }
    }

    // 2. Advance persisted stage to installingLocally before opening the SQLite
    // replacement transaction.
    if (activeTransfer.stage != RestoreTransferStage.installingLocally) {
      activeTransfer = activeTransfer.copyWith(
        stage: RestoreTransferStage.installingLocally,
        isTakeoverOutcomeUnknown: false,
      );
      await _transferStorage.writePendingTransfer(
        transfer: activeTransfer,
        stagedSnapshot: activeSnapshot,
      );
    }

    final installConsent = RestoreConsentToken(
      version: activeSnapshot.preview.version,
      activeDeviceId: activeSnapshot.preview.activeDeviceId,
      confirmedAt: activeSnapshot.preview.confirmedAt,
      ownerUserId: activeTransfer.ownerUserId,
      localDeviceId: activeTransfer.targetDeviceId,
      localRevisionStamp: activeTransfer.consentedLocalRevisionStamp,
      requiresTakeover: activeTransfer.requiresTakeover,
      requiresReplacement: activeTransfer.requiresReplacement,
      primaryConfirmed: true,
      replacementConfirmed: !activeTransfer.requiresReplacement || true,
    );

    switch (await _localStore.installConfirmedSnapshot(
      snapshot: activeSnapshot,
      consent: installConsent,
    )) {
      case Left(:final value):
        return Left(value);
      case Right(
        value: RestoreLocalInstallBlockedAccountMismatch(:final localLedger),
      ):
        if (!activeTransfer.requiresTakeover) {
          await _transferStorage.clearPendingTransfer(
            requestId: activeTransfer.requestId,
          );
          await _notifyExternalStateChanged?.call();
        }
        return Right(
          RestoreExecutionBlockedAccountMismatch(
            account: account,
            localLedger: localLedger,
          ),
        );
      case Right(
        value: RestoreLocalInstallBlockedLocalLedgerChanged(
          :final updatedLocalLedger,
        ),
      ):
        // P13-02: If takeover already committed on the server, keep the
        // persisted transfer and upload block intact in _transferStorage (at
        // stage takeoverConfirmed) so the receiving phone cannot publish rows
        // from its old ledger before fresh replacement consent is granted and
        // local installation succeeds!
        if (activeTransfer.requiresTakeover) {
          activeTransfer = activeTransfer.copyWith(
            stage: RestoreTransferStage.takeoverConfirmed,
            isTakeoverOutcomeUnknown: false,
          );
          await _transferStorage.writePendingTransfer(
            transfer: activeTransfer,
            stagedSnapshot: activeSnapshot,
          );
        } else {
          await _transferStorage.clearPendingTransfer(
            requestId: activeTransfer.requestId,
          );
        }
        await _notifyExternalStateChanged?.call();
        return Right(
          RestoreExecutionLocalLedgerChanged(
            account: account,
            updatedLocalLedger: updatedLocalLedger,
            cloudPreview: activeSnapshot.preview,
          ),
        );
      case Right(value: RestoreLocalInstallBlockedSessionInvalidated()):
        return const Left(AppFailure(AppErrorCode.auth));
      case Right(
        value: RestoreLocalInstallApplied(
          :final localLedger,
          :final scheduleState,
        ),
      ):
        if (afterLocalCommitBeforeClearHook != null) {
          try {
            await afterLocalCommitBeforeClearHook!(activeTransfer);
          } on RestoreStageInterruption {
            return Right(
              RestoreExecutionInterrupted(
                account: account,
                localLedger: localLedger,
                pendingTransfer: activeTransfer,
              ),
            );
          }
        }

        await _transferStorage.clearPendingTransfer(
          requestId: activeTransfer.requestId,
        );
        try {
          if (scheduleState.hasSchedule) {
            await _scheduler.syncSchedule(
              scheduleState,
              now: _dateService.now(),
            );
          }
        } catch (_) {
          // Best-effort schedule sync; BackupCubit also reconciles on refresh.
        }
        await _notifyExternalStateChanged?.call();

        return Right(
          RestoreExecutionSucceeded(
            account: account,
            cloudPreview: activeSnapshot.preview,
            localLedger: localLedger,
            authorityTransferred: activeTransfer.requiresTakeover,
          ),
        );
    }
  }

  Either<AppFailure, RestoreExecutionResult> _handleTransferFailure(
    AppFailure failure, {
    required RestoreAccountInfo account,
    required RestoreLocalLedgerSummary localLedger,
    required PendingRestoreTransfer transfer,
  }) {
    if (failure.errorCode == AppErrorCode.network) {
      return Right(
        RestoreExecutionInterrupted(
          account: account,
          localLedger: localLedger,
          pendingTransfer: transfer,
        ),
      );
    }
    return Left(failure);
  }

  Future<CloudBackupSnapshotPreview> _readPreviewOrFallbackFromConsent(
    RestoreConsentToken consent,
  ) => _readLatestCloudPreview(
    fallback: CloudBackupSnapshotPreview(
      version: consent.version,
      ownerUserId: consent.ownerUserId,
      activeDeviceId: consent.activeDeviceId,
      confirmedAt: consent.confirmedAt,
    ),
  );

  Future<CloudBackupSnapshotPreview> _readLatestCloudPreview({
    required CloudBackupSnapshotPreview fallback,
  }) async {
    final result = await _cloudService.readConfirmedSnapshot();
    return result.fold(
      (_) => fallback,
      (read) => switch (read) {
        RestoreCloudSnapshotMissing() => fallback,
        RestoreCloudSnapshotVersionChanged(:final preview) => preview,
        RestoreCloudSnapshotFound(:final snapshot) => snapshot.preview,
      },
    );
  }
}
