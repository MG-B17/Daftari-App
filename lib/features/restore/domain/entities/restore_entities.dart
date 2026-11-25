import 'package:equatable/equatable.dart';

import '../../../backup/domain/entities/backup_batch.dart';

/// Authenticated account summary used during cloud restore preview and consent.
final class RestoreAccountInfo extends Equatable {
  const RestoreAccountInfo({
    required this.userId,
    required this.email,
    this.shopName,
    this.isEmailVerified = true,
  });

  final String userId;
  final String email;
  final String? shopName;
  final bool isEmailVerified;

  @override
  List<Object?> get props => [userId, email, shopName, isEmailVerified];
}

/// Summary of the receiving phone's current local ledger state, including
/// soft-deleted tombstones, append-only audit history, pending changes, and a
/// revision stamp that changes whenever any local record is mutated.
final class RestoreLocalLedgerSummary extends Equatable {
  const RestoreLocalLedgerSummary({
    required this.deviceId,
    this.linkedOwnerUserId,
    this.isActiveDevice = true,
    this.customerCount = 0,
    this.deletedCustomerCount = 0,
    this.transactionCount = 0,
    this.deletedTransactionCount = 0,
    this.auditLogCount = 0,
    this.pendingChangesCount = 0,
    this.revisionStamp = 'rev-0',
  }) : assert(customerCount >= 0),
       assert(deletedCustomerCount >= 0),
       assert(transactionCount >= 0),
       assert(deletedTransactionCount >= 0),
       assert(auditLogCount >= 0),
       assert(pendingChangesCount >= 0);

  final String? linkedOwnerUserId;
  final String deviceId;
  final bool isActiveDevice;
  final int customerCount;
  final int deletedCustomerCount;
  final int transactionCount;
  final int deletedTransactionCount;
  final int auditLogCount;
  final int pendingChangesCount;
  final String revisionStamp;

  int get totalCustomerCount => customerCount + deletedCustomerCount;

  int get totalTransactionCount => transactionCount + deletedTransactionCount;

  int get deletedAndAuditCount =>
      deletedCustomerCount + deletedTransactionCount + auditLogCount;

  int get totalRecordCount =>
      totalCustomerCount + totalTransactionCount + auditLogCount;

  /// A ledger containing only deleted records (tombstones) or audit history
  /// still counts as populated and requires explicit replacement confirmation.
  bool get isPopulated => totalRecordCount > 0;

  bool get isEmpty => !isPopulated;

  bool get hasPendingChanges => pendingChangesCount > 0;

  bool get hasLinkedOwner =>
      linkedOwnerUserId != null && linkedOwnerUserId!.trim().isNotEmpty;

  bool isAccountMismatchFor(String authenticatedUserId) =>
      hasLinkedOwner && linkedOwnerUserId != authenticatedUserId;

  RestoreLocalLedgerSummary copyWith({
    String? Function()? linkedOwnerUserId,
    String? deviceId,
    bool? isActiveDevice,
    int? customerCount,
    int? deletedCustomerCount,
    int? transactionCount,
    int? deletedTransactionCount,
    int? auditLogCount,
    int? pendingChangesCount,
    String? revisionStamp,
  }) => RestoreLocalLedgerSummary(
    linkedOwnerUserId: linkedOwnerUserId != null
        ? linkedOwnerUserId()
        : this.linkedOwnerUserId,
    deviceId: deviceId ?? this.deviceId,
    isActiveDevice: isActiveDevice ?? this.isActiveDevice,
    customerCount: customerCount ?? this.customerCount,
    deletedCustomerCount: deletedCustomerCount ?? this.deletedCustomerCount,
    transactionCount: transactionCount ?? this.transactionCount,
    deletedTransactionCount:
        deletedTransactionCount ?? this.deletedTransactionCount,
    auditLogCount: auditLogCount ?? this.auditLogCount,
    pendingChangesCount: pendingChangesCount ?? this.pendingChangesCount,
    revisionStamp: revisionStamp ?? this.revisionStamp,
  );

  @override
  List<Object?> get props => [
    linkedOwnerUserId,
    deviceId,
    isActiveDevice,
    customerCount,
    deletedCustomerCount,
    transactionCount,
    deletedTransactionCount,
    auditLogCount,
    pendingChangesCount,
    revisionStamp,
  ];
}

/// Consistent confirmed cloud ledger version metadata and record counts.
///
/// A valid confirmed snapshot with zero rows (`hasZeroRows == true`) is
/// explicitly represented as a [CloudBackupSnapshotPreview] with zero counts,
/// distinct from a missing cloud backup (`null`).
final class CloudBackupSnapshotPreview extends Equatable {
  CloudBackupSnapshotPreview({
    required this.version,
    required this.ownerUserId,
    required this.activeDeviceId,
    required DateTime confirmedAt,
    this.customerCount = 0,
    this.deletedCustomerCount = 0,
    this.transactionCount = 0,
    this.deletedTransactionCount = 0,
    this.auditLogCount = 0,
  }) : assert(customerCount >= 0),
       assert(deletedCustomerCount >= 0),
       assert(transactionCount >= 0),
       assert(deletedTransactionCount >= 0),
       assert(auditLogCount >= 0),
       confirmedAt = confirmedAt.toUtc();

  final String version;
  final String ownerUserId;
  final String activeDeviceId;
  final DateTime confirmedAt;
  final int customerCount;
  final int deletedCustomerCount;
  final int transactionCount;
  final int deletedTransactionCount;
  final int auditLogCount;

  int get totalCustomerCount => customerCount + deletedCustomerCount;

  int get totalTransactionCount => transactionCount + deletedTransactionCount;

  int get deletedAndAuditCount =>
      deletedCustomerCount + deletedTransactionCount + auditLogCount;

  int get totalRecordCount =>
      totalCustomerCount + totalTransactionCount + auditLogCount;

  bool get hasZeroRows => totalRecordCount == 0;

  CloudBackupSnapshotPreview copyWith({
    String? version,
    String? ownerUserId,
    String? activeDeviceId,
    DateTime? confirmedAt,
    int? customerCount,
    int? deletedCustomerCount,
    int? transactionCount,
    int? deletedTransactionCount,
    int? auditLogCount,
  }) => CloudBackupSnapshotPreview(
    version: version ?? this.version,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    activeDeviceId: activeDeviceId ?? this.activeDeviceId,
    confirmedAt: confirmedAt ?? this.confirmedAt,
    customerCount: customerCount ?? this.customerCount,
    deletedCustomerCount: deletedCustomerCount ?? this.deletedCustomerCount,
    transactionCount: transactionCount ?? this.transactionCount,
    deletedTransactionCount:
        deletedTransactionCount ?? this.deletedTransactionCount,
    auditLogCount: auditLogCount ?? this.auditLogCount,
  );

  @override
  List<Object?> get props => [
    version,
    ownerUserId,
    activeDeviceId,
    confirmedAt,
    customerCount,
    deletedCustomerCount,
    transactionCount,
    deletedTransactionCount,
    auditLogCount,
  ];
}

/// Full cumulative cloud ledger snapshot bound to a single consistent
/// server-confirmed [preview] version.
final class CloudBackupSnapshot extends Equatable {
  CloudBackupSnapshot({
    required this.preview,
    required List<BackupCustomerRecord> customers,
    required List<BackupTransactionRecord> transactions,
    required List<BackupAuditLogRecord> auditLogs,
  }) : customers = List.unmodifiable(customers),
       transactions = List.unmodifiable(transactions),
       auditLogs = List.unmodifiable(auditLogs);

  final CloudBackupSnapshotPreview preview;
  final List<BackupCustomerRecord> customers;
  final List<BackupTransactionRecord> transactions;
  final List<BackupAuditLogRecord> auditLogs;

  @override
  List<Object?> get props => [preview, customers, transactions, auditLogs];
}

enum RestoreTransferStage {
  takeoverPending,
  takeoverConfirmed,
  installingLocally,
}

/// Durable transfer and restore progress persisted before requesting takeover
/// so an interrupted operation can recover safely across process death or lost
/// network responses while keeping uploads blocked until local install finishes.
final class PendingRestoreTransfer extends Equatable {
  PendingRestoreTransfer({
    required this.requestId,
    required this.ownerUserId,
    required this.targetDeviceId,
    required this.expectedVersion,
    required this.expectedActiveDeviceId,
    required DateTime confirmedAt,
    required this.requiresTakeover,
    required this.requiresReplacement,
    required this.consentedLocalRevisionStamp,
    required this.stage,
    required this.cloudPreview,
  }) : confirmedAt = confirmedAt.toUtc();

  final String requestId;
  final String ownerUserId;
  final String targetDeviceId;
  final String expectedVersion;
  final String expectedActiveDeviceId;
  final DateTime confirmedAt;
  final bool requiresTakeover;
  final bool requiresReplacement;
  final String consentedLocalRevisionStamp;
  final RestoreTransferStage stage;
  final CloudBackupSnapshotPreview cloudPreview;

  bool get canCancelBeforeServerTakeover =>
      stage == RestoreTransferStage.takeoverPending;

  PendingRestoreTransfer copyWith({
    RestoreTransferStage? stage,
    CloudBackupSnapshotPreview? cloudPreview,
  }) => PendingRestoreTransfer(
    requestId: requestId,
    ownerUserId: ownerUserId,
    targetDeviceId: targetDeviceId,
    expectedVersion: expectedVersion,
    expectedActiveDeviceId: expectedActiveDeviceId,
    confirmedAt: confirmedAt,
    requiresTakeover: requiresTakeover,
    requiresReplacement: requiresReplacement,
    consentedLocalRevisionStamp: consentedLocalRevisionStamp,
    stage: stage ?? this.stage,
    cloudPreview: cloudPreview ?? this.cloudPreview,
  );

  @override
  List<Object?> get props => [
    requestId,
    ownerUserId,
    targetDeviceId,
    expectedVersion,
    expectedActiveDeviceId,
    confirmedAt,
    requiresTakeover,
    requiresReplacement,
    consentedLocalRevisionStamp,
    stage,
    cloudPreview,
  ];
}

/// Explicit user consent token binding preview, download, takeover, and local
/// replacement to the exact confirmed cloud [version], [activeDeviceId], and
/// [localRevisionStamp].
final class RestoreConsentToken extends Equatable {
  RestoreConsentToken({
    required this.version,
    required this.activeDeviceId,
    required DateTime confirmedAt,
    required this.ownerUserId,
    required this.localDeviceId,
    required this.localRevisionStamp,
    required this.requiresTakeover,
    required this.requiresReplacement,
    required this.primaryConfirmed,
    required this.replacementConfirmed,
  }) : confirmedAt = confirmedAt.toUtc();

  final String version;
  final String activeDeviceId;
  final DateTime confirmedAt;
  final String ownerUserId;
  final String localDeviceId;
  final String localRevisionStamp;
  final bool requiresTakeover;
  final bool requiresReplacement;
  final bool primaryConfirmed;
  final bool replacementConfirmed;

  /// Only permits execution when the primary confirmation is granted AND, for
  /// populated local ledgers, the second explicit replacement confirmation is
  /// also granted.
  bool get isFullyPermitted =>
      primaryConfirmed && (!requiresReplacement || replacementConfirmed);

  @override
  List<Object?> get props => [
    version,
    activeDeviceId,
    confirmedAt,
    ownerUserId,
    localDeviceId,
    localRevisionStamp,
    requiresTakeover,
    requiresReplacement,
    primaryConfirmed,
    replacementConfirmed,
  ];
}

/// Outcome of inspecting eligibility, local ledger state, pending transfer
/// recovery, and the latest confirmed cloud snapshot.
sealed class RestoreInspectionResult extends Equatable {
  const RestoreInspectionResult();

  @override
  List<Object?> get props => [];
}

final class RestoreInspectionSignedOut extends RestoreInspectionResult {
  const RestoreInspectionSignedOut();
}

final class RestoreInspectionEmailUnverified extends RestoreInspectionResult {
  const RestoreInspectionEmailUnverified({required this.email, this.shopName});

  final String email;
  final String? shopName;

  @override
  List<Object?> get props => [email, shopName];
}

final class RestoreInspectionAccountMismatch extends RestoreInspectionResult {
  const RestoreInspectionAccountMismatch({
    required this.account,
    required this.localLedger,
  });

  final RestoreAccountInfo account;
  final RestoreLocalLedgerSummary localLedger;

  @override
  List<Object?> get props => [account, localLedger];
}

final class RestoreInspectionOffline extends RestoreInspectionResult {
  const RestoreInspectionOffline({
    required this.account,
    required this.localLedger,
    this.pendingTransfer,
  });

  final RestoreAccountInfo account;
  final RestoreLocalLedgerSummary localLedger;
  final PendingRestoreTransfer? pendingTransfer;

  @override
  List<Object?> get props => [account, localLedger, pendingTransfer];
}

final class RestoreInspectionMissingBackup extends RestoreInspectionResult {
  const RestoreInspectionMissingBackup({
    required this.account,
    required this.localLedger,
  });

  final RestoreAccountInfo account;
  final RestoreLocalLedgerSummary localLedger;

  @override
  List<Object?> get props => [account, localLedger];
}

final class RestoreInspectionInterruptedTransfer
    extends RestoreInspectionResult {
  const RestoreInspectionInterruptedTransfer({
    required this.account,
    required this.localLedger,
    required this.pendingTransfer,
  });

  final RestoreAccountInfo account;
  final RestoreLocalLedgerSummary localLedger;
  final PendingRestoreTransfer pendingTransfer;

  @override
  List<Object?> get props => [account, localLedger, pendingTransfer];
}

final class RestoreInspectionReady extends RestoreInspectionResult {
  const RestoreInspectionReady({
    required this.account,
    required this.localLedger,
    required this.cloudPreview,
  });

  final RestoreAccountInfo account;
  final RestoreLocalLedgerSummary localLedger;
  final CloudBackupSnapshotPreview cloudPreview;

  bool get requiresTakeover =>
      localLedger.deviceId != cloudPreview.activeDeviceId;

  bool get requiresReplacement => localLedger.isPopulated;

  @override
  List<Object?> get props => [account, localLedger, cloudPreview];
}

/// Outcome of executing a consented restore or resuming an interrupted transfer.
sealed class RestoreExecutionResult extends Equatable {
  const RestoreExecutionResult();

  @override
  List<Object?> get props => [];
}

final class RestoreExecutionSucceeded extends RestoreExecutionResult {
  const RestoreExecutionSucceeded({
    required this.account,
    required this.cloudPreview,
    required this.localLedger,
    required this.authorityTransferred,
  });

  final RestoreAccountInfo account;
  final CloudBackupSnapshotPreview cloudPreview;
  final RestoreLocalLedgerSummary localLedger;
  final bool authorityTransferred;

  @override
  List<Object?> get props => [
    account,
    cloudPreview,
    localLedger,
    authorityTransferred,
  ];
}

final class RestoreExecutionCloudVersionChanged extends RestoreExecutionResult {
  const RestoreExecutionCloudVersionChanged({
    required this.account,
    required this.localLedger,
    required this.updatedCloudPreview,
  });

  final RestoreAccountInfo account;
  final RestoreLocalLedgerSummary localLedger;
  final CloudBackupSnapshotPreview updatedCloudPreview;

  @override
  List<Object?> get props => [account, localLedger, updatedCloudPreview];
}

final class RestoreExecutionLocalLedgerChanged extends RestoreExecutionResult {
  const RestoreExecutionLocalLedgerChanged({
    required this.account,
    required this.updatedLocalLedger,
    required this.cloudPreview,
  });

  final RestoreAccountInfo account;
  final RestoreLocalLedgerSummary updatedLocalLedger;
  final CloudBackupSnapshotPreview cloudPreview;

  @override
  List<Object?> get props => [account, updatedLocalLedger, cloudPreview];
}

final class RestoreExecutionBlockedAccountMismatch
    extends RestoreExecutionResult {
  const RestoreExecutionBlockedAccountMismatch({
    required this.account,
    required this.localLedger,
  });

  final RestoreAccountInfo account;
  final RestoreLocalLedgerSummary localLedger;

  @override
  List<Object?> get props => [account, localLedger];
}

final class RestoreExecutionOffline extends RestoreExecutionResult {
  const RestoreExecutionOffline({
    required this.account,
    required this.localLedger,
    this.pendingTransfer,
  });

  final RestoreAccountInfo account;
  final RestoreLocalLedgerSummary localLedger;
  final PendingRestoreTransfer? pendingTransfer;

  @override
  List<Object?> get props => [account, localLedger, pendingTransfer];
}

final class RestoreExecutionInterrupted extends RestoreExecutionResult {
  const RestoreExecutionInterrupted({
    required this.account,
    required this.localLedger,
    required this.pendingTransfer,
  });

  final RestoreAccountInfo account;
  final RestoreLocalLedgerSummary localLedger;
  final PendingRestoreTransfer pendingTransfer;

  @override
  List<Object?> get props => [account, localLedger, pendingTransfer];
}

/// Outcome of reading the authenticated account's cumulative confirmed cloud
/// snapshot at a single consistent server version.
sealed class RestoreCloudSnapshotReadResult extends Equatable {
  const RestoreCloudSnapshotReadResult();

  @override
  List<Object?> get props => [];
}

final class RestoreCloudSnapshotMissing extends RestoreCloudSnapshotReadResult {
  const RestoreCloudSnapshotMissing();
}

final class RestoreCloudSnapshotVersionChanged
    extends RestoreCloudSnapshotReadResult {
  const RestoreCloudSnapshotVersionChanged({required this.preview});

  final CloudBackupSnapshotPreview preview;

  @override
  List<Object?> get props => [preview];
}

final class RestoreCloudSnapshotFound extends RestoreCloudSnapshotReadResult {
  const RestoreCloudSnapshotFound({required this.snapshot});

  final CloudBackupSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot];
}

enum RestorePreconditionFailureReason { versionChanged, activeDeviceChanged }

/// Outcome of requesting or recovering a server-serialized backup authority
/// transfer to the receiving phone.
sealed class RestoreAuthorityTransferResult extends Equatable {
  const RestoreAuthorityTransferResult();

  @override
  List<Object?> get props => [];
}

final class RestoreAuthorityTransferred extends RestoreAuthorityTransferResult {
  RestoreAuthorityTransferred({
    required this.requestId,
    required this.version,
    required this.activeDeviceId,
    required DateTime confirmedAt,
    required DateTime transferredAt,
  }) : confirmedAt = confirmedAt.toUtc(),
       transferredAt = transferredAt.toUtc();

  final String requestId;
  final String version;
  final String activeDeviceId;
  final DateTime confirmedAt;
  final DateTime transferredAt;

  @override
  List<Object?> get props => [
    requestId,
    version,
    activeDeviceId,
    confirmedAt,
    transferredAt,
  ];
}

final class RestoreAuthorityPreconditionFailed
    extends RestoreAuthorityTransferResult {
  RestoreAuthorityPreconditionFailed({
    required this.reason,
    required this.currentVersion,
    required this.activeDeviceId,
    required DateTime confirmedAt,
  }) : confirmedAt = confirmedAt.toUtc();

  final RestorePreconditionFailureReason reason;
  final String currentVersion;
  final String activeDeviceId;
  final DateTime confirmedAt;

  @override
  List<Object?> get props => [
    reason,
    currentVersion,
    activeDeviceId,
    confirmedAt,
  ];
}

final class RestoreAuthorityMissingBackup
    extends RestoreAuthorityTransferResult {
  const RestoreAuthorityMissingBackup();
}
