import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../auth/session/presentation/cubit/auth_session_state.dart';
import '../../domain/entities/restore_entities.dart';
import '../../domain/repositories/restore_repository.dart';

/// Deterministic in-memory [RestoreRepository] implementation driving the Task 1
/// Settings → Backup → Restore flow and widget/cubit verification suites.
class FakeRestoreRepository implements RestoreRepository {
  FakeRestoreRepository({
    this.account,
    this.readAuthState,
    RestoreLocalLedgerSummary? localLedger,
    this.cloudPreview,
    this.pendingTransfer,
    this.isOnline = true,
    this.isPreview = false,
  }) : localLedger =
           localLedger ??
           const RestoreLocalLedgerSummary(deviceId: 'device-receiving-1');

  RestoreAccountInfo? account;
  final AuthSessionState Function()? readAuthState;
  RestoreLocalLedgerSummary localLedger;
  CloudBackupSnapshotPreview? cloudPreview;
  PendingRestoreTransfer? pendingTransfer;
  bool isOnline;
  final bool isPreview;

  /// When set, the next [executeRestore] call persists transfer progress at
  /// [interruptNextExecutionAtStage] and returns [RestoreExecutionInterrupted]
  /// while leaving [localLedger] intact.
  RestoreTransferStage? interruptNextExecutionAtStage;

  AppFailure? nextFailure;
  Future<void> Function()? onBeforeExecuteRestore;

  int inspectCalls = 0;
  int executeCalls = 0;
  int resumeCalls = 0;
  int discardCalls = 0;
  int completedRestoreCount = 0;
  int completedTakeoverCount = 0;
  int _requestSequence = 0;
  int _localRevisionSequence = 0;
  final List<RestoreConsentToken> receivedConsents = [];

  /// Uploads remain blocked on the receiving phone while a transfer is pending.
  bool get areUploadsBlocked => pendingTransfer != null;

  /// Simulates a new local edit on the receiving phone after preview/consent,
  /// incrementing local counts and advancing [RestoreLocalLedgerSummary.revisionStamp]
  /// so prior replacement consent is invalidated.
  void recordLocalEdit({
    int addedCustomers = 0,
    int addedDeletedCustomers = 0,
    int addedTransactions = 0,
    int addedDeletedTransactions = 0,
    int addedAuditLogs = 0,
    int addedPendingChanges = 1,
  }) {
    _localRevisionSequence++;
    localLedger = localLedger.copyWith(
      customerCount: localLedger.customerCount + addedCustomers,
      deletedCustomerCount:
          localLedger.deletedCustomerCount + addedDeletedCustomers,
      transactionCount: localLedger.transactionCount + addedTransactions,
      deletedTransactionCount:
          localLedger.deletedTransactionCount + addedDeletedTransactions,
      auditLogCount: localLedger.auditLogCount + addedAuditLogs,
      pendingChangesCount:
          localLedger.pendingChangesCount + addedPendingChanges,
      revisionStamp: 'rev-edit-$_localRevisionSequence',
    );
  }

  /// Simulates a concurrent server publication or takeover by another device
  /// between preview and confirmation.
  void updateCloudSnapshot({
    required String version,
    required DateTime confirmedAt,
    String? activeDeviceId,
    int? customerCount,
    int? deletedCustomerCount,
    int? transactionCount,
    int? deletedTransactionCount,
    int? auditLogCount,
  }) {
    final current = cloudPreview;
    final resolvedOwnerId =
        current?.ownerUserId ?? _resolveAccount()?.userId ?? 'user-a';
    cloudPreview = CloudBackupSnapshotPreview(
      version: version,
      ownerUserId: resolvedOwnerId,
      activeDeviceId: activeDeviceId ?? current?.activeDeviceId ?? 'device-old',
      confirmedAt: confirmedAt,
      customerCount: customerCount ?? current?.customerCount ?? 0,
      deletedCustomerCount:
          deletedCustomerCount ?? current?.deletedCustomerCount ?? 0,
      transactionCount: transactionCount ?? current?.transactionCount ?? 0,
      deletedTransactionCount:
          deletedTransactionCount ?? current?.deletedTransactionCount ?? 0,
      auditLogCount: auditLogCount ?? current?.auditLogCount ?? 0,
    );
  }

  RestoreAccountInfo? _resolveAccount() {
    if (account != null) return account;
    final authReader = readAuthState;
    if (authReader == null) return null;
    final authState = authReader();
    if (authState.status == AuthStatus.emailVerificationRequired) {
      final email = authState.pendingEmail ?? authState.user?.email ?? '';
      return RestoreAccountInfo(
        userId: authState.user?.id ?? '',
        email: email,
        shopName: authState.user?.shopName,
        isEmailVerified: false,
      );
    }
    final user = authState.isAuthenticated ? authState.user : null;
    if (user == null) return null;
    return RestoreAccountInfo(
      userId: user.id,
      email: user.email,
      shopName: user.shopName,
      isEmailVerified: user.emailVerified,
    );
  }

  @override
  Future<Either<AppFailure, RestoreInspectionResult>> inspectRestore() async {
    inspectCalls++;
    if (nextFailure case final failure?) {
      nextFailure = null;
      return Left(failure);
    }

    final resolvedAccount = _resolveAccount();
    if (resolvedAccount == null) {
      return const Right(RestoreInspectionSignedOut());
    }
    if (!resolvedAccount.isEmailVerified) {
      return Right(
        RestoreInspectionEmailUnverified(
          email: resolvedAccount.email,
          shopName: resolvedAccount.shopName,
        ),
      );
    }
    if (localLedger.isAccountMismatchFor(resolvedAccount.userId)) {
      return Right(
        RestoreInspectionAccountMismatch(
          account: resolvedAccount,
          localLedger: localLedger,
        ),
      );
    }
    if (pendingTransfer case final inFlight?
        when inFlight.ownerUserId == resolvedAccount.userId) {
      if (!isOnline) {
        return Right(
          RestoreInspectionOffline(
            account: resolvedAccount,
            localLedger: localLedger,
            pendingTransfer: inFlight,
          ),
        );
      }
      return Right(
        RestoreInspectionInterruptedTransfer(
          account: resolvedAccount,
          localLedger: localLedger,
          pendingTransfer: inFlight,
        ),
      );
    }
    if (!isOnline) {
      return Right(
        RestoreInspectionOffline(
          account: resolvedAccount,
          localLedger: localLedger,
        ),
      );
    }
    final snapshot = cloudPreview;
    if (snapshot == null || snapshot.ownerUserId != resolvedAccount.userId) {
      return Right(
        RestoreInspectionMissingBackup(
          account: resolvedAccount,
          localLedger: localLedger,
        ),
      );
    }
    return Right(
      RestoreInspectionReady(
        account: resolvedAccount,
        localLedger: localLedger,
        cloudPreview: snapshot,
      ),
    );
  }

  @override
  Future<Either<AppFailure, RestoreExecutionResult>> executeRestore({
    required RestoreConsentToken consent,
  }) async {
    executeCalls++;
    receivedConsents.add(consent);
    if (onBeforeExecuteRestore case final hook?) {
      await hook();
    }
    if (nextFailure case final failure?) {
      nextFailure = null;
      return Left(failure);
    }
    if (!consent.isFullyPermitted) {
      return const Left(AppFailure(AppErrorCode.validation));
    }

    final resolvedAccount = _resolveAccount();
    if (resolvedAccount == null ||
        !resolvedAccount.isEmailVerified ||
        resolvedAccount.userId != consent.ownerUserId) {
      return const Left(AppFailure(AppErrorCode.auth));
    }
    if (localLedger.isAccountMismatchFor(resolvedAccount.userId)) {
      return Right(
        RestoreExecutionBlockedAccountMismatch(
          account: resolvedAccount,
          localLedger: localLedger,
        ),
      );
    }
    final snapshot = cloudPreview;
    if (snapshot == null || snapshot.ownerUserId != resolvedAccount.userId) {
      return const Left(AppFailure(AppErrorCode.validation));
    }

    // Recheck local ledger population and revision stamp before replacement.
    if (localLedger.isPopulated && !consent.replacementConfirmed) {
      return const Left(AppFailure(AppErrorCode.validation));
    }
    if (localLedger.revisionStamp != consent.localRevisionStamp ||
        localLedger.deviceId != consent.localDeviceId) {
      return Right(
        RestoreExecutionLocalLedgerChanged(
          account: resolvedAccount,
          updatedLocalLedger: localLedger,
          cloudPreview: snapshot,
        ),
      );
    }

    if (!isOnline) {
      return Right(
        RestoreExecutionOffline(
          account: resolvedAccount,
          localLedger: localLedger,
          pendingTransfer: pendingTransfer,
        ),
      );
    }

    // Compare expected cloud version and active device before takeover/install.
    if (snapshot.version != consent.version ||
        snapshot.activeDeviceId != consent.activeDeviceId) {
      return Right(
        RestoreExecutionCloudVersionChanged(
          account: resolvedAccount,
          localLedger: localLedger,
          updatedCloudPreview: snapshot,
        ),
      );
    }

    final requiresTakeover = localLedger.deviceId != snapshot.activeDeviceId;
    if (requiresTakeover != consent.requiresTakeover) {
      return Right(
        RestoreExecutionCloudVersionChanged(
          account: resolvedAccount,
          localLedger: localLedger,
          updatedCloudPreview: snapshot,
        ),
      );
    }

    // Persist transfer progress before requesting takeover.
    final requestId = 'transfer-req-${++_requestSequence}';
    final persistedTransfer = PendingRestoreTransfer(
      requestId: requestId,
      ownerUserId: resolvedAccount.userId,
      targetDeviceId: localLedger.deviceId,
      expectedVersion: snapshot.version,
      expectedActiveDeviceId: snapshot.activeDeviceId,
      confirmedAt: snapshot.confirmedAt,
      requiresTakeover: requiresTakeover,
      requiresReplacement: localLedger.isPopulated,
      consentedLocalRevisionStamp: localLedger.revisionStamp,
      stage:
          interruptNextExecutionAtStage ??
          (requiresTakeover
              ? RestoreTransferStage.takeoverConfirmed
              : RestoreTransferStage.installingLocally),
      cloudPreview: snapshot,
    );
    pendingTransfer = persistedTransfer;

    if (interruptNextExecutionAtStage case final interruptedStage?) {
      interruptNextExecutionAtStage = null;
      if (interruptedStage == RestoreTransferStage.takeoverConfirmed &&
          requiresTakeover) {
        // Server committed takeover before response/install was interrupted.
        cloudPreview = snapshot.copyWith(activeDeviceId: localLedger.deviceId);
      }
      return Right(
        RestoreExecutionInterrupted(
          account: resolvedAccount,
          localLedger: localLedger,
          pendingTransfer: persistedTransfer,
        ),
      );
    }

    return _completeInstallation(
      account: resolvedAccount,
      transfer: persistedTransfer,
      snapshot: snapshot,
    );
  }

  @override
  Future<Either<AppFailure, RestoreExecutionResult>> resumePendingTransfer(
    PendingRestoreTransfer transfer,
  ) async {
    resumeCalls++;
    if (nextFailure case final failure?) {
      nextFailure = null;
      return Left(failure);
    }

    final resolvedAccount = _resolveAccount();
    if (resolvedAccount == null ||
        !resolvedAccount.isEmailVerified ||
        resolvedAccount.userId != transfer.ownerUserId) {
      return const Left(AppFailure(AppErrorCode.auth));
    }
    if (localLedger.isAccountMismatchFor(resolvedAccount.userId)) {
      return Right(
        RestoreExecutionBlockedAccountMismatch(
          account: resolvedAccount,
          localLedger: localLedger,
        ),
      );
    }
    if (!isOnline) {
      return Right(
        RestoreExecutionOffline(
          account: resolvedAccount,
          localLedger: localLedger,
          pendingTransfer: transfer,
        ),
      );
    }

    final latestSnapshot = cloudPreview ?? transfer.cloudPreview;
    if (localLedger.revisionStamp != transfer.consentedLocalRevisionStamp) {
      pendingTransfer = null;
      return Right(
        RestoreExecutionLocalLedgerChanged(
          account: resolvedAccount,
          updatedLocalLedger: localLedger,
          cloudPreview: latestSnapshot,
        ),
      );
    }

    // If takeover was not yet committed on the server and the cloud version or
    // active device changed in the meantime, refresh preview and ask again.
    if (transfer.stage == RestoreTransferStage.takeoverPending &&
        (latestSnapshot.version != transfer.expectedVersion ||
            latestSnapshot.activeDeviceId != transfer.expectedActiveDeviceId)) {
      pendingTransfer = null;
      return Right(
        RestoreExecutionCloudVersionChanged(
          account: resolvedAccount,
          localLedger: localLedger,
          updatedCloudPreview: latestSnapshot,
        ),
      );
    }

    return _completeInstallation(
      account: resolvedAccount,
      transfer: transfer,
      snapshot: transfer.cloudPreview,
    );
  }

  @override
  Future<Either<AppFailure, void>> discardPendingTransfer(
    String requestId,
  ) async {
    discardCalls++;
    if (nextFailure case final failure?) {
      nextFailure = null;
      return Left(failure);
    }
    final current = pendingTransfer;
    if (current != null && current.requestId == requestId) {
      if (!current.canCancelBeforeServerTakeover) {
        return const Left(AppFailure(AppErrorCode.validation));
      }
      pendingTransfer = null;
    }
    return const Right(null);
  }

  Either<AppFailure, RestoreExecutionResult> _completeInstallation({
    required RestoreAccountInfo account,
    required PendingRestoreTransfer transfer,
    required CloudBackupSnapshotPreview snapshot,
  }) {
    final updatedCloud = snapshot.copyWith(
      activeDeviceId: localLedger.deviceId,
    );
    cloudPreview = updatedCloud;
    localLedger = RestoreLocalLedgerSummary(
      linkedOwnerUserId: account.userId,
      deviceId: localLedger.deviceId,
      isActiveDevice: true,
      customerCount: updatedCloud.customerCount,
      deletedCustomerCount: updatedCloud.deletedCustomerCount,
      transactionCount: updatedCloud.transactionCount,
      deletedTransactionCount: updatedCloud.deletedTransactionCount,
      auditLogCount: updatedCloud.auditLogCount,
      pendingChangesCount: 0,
      revisionStamp: 'restored-${updatedCloud.version}',
    );
    pendingTransfer = null;
    completedRestoreCount++;
    if (transfer.requiresTakeover) {
      completedTakeoverCount++;
    }
    return Right(
      RestoreExecutionSucceeded(
        account: account,
        cloudPreview: updatedCloud,
        localLedger: localLedger,
        authorityTransferred: transfer.requiresTakeover,
      ),
    );
  }
}
