import 'package:equatable/equatable.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';
import 'backup_eligibility.dart';
import 'backup_schedule.dart';

enum BackupAuditAction { edit, delete }

/// Immutable customer values and revision captured at batch cutoff.
final class BackupCustomerRecord extends Equatable {
  const BackupCustomerRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.localRevision,
  }) : assert(localRevision >= 1);

  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int localRevision;

  bool get isDeleted => deletedAt != null;

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
    localRevision,
  ];
}

/// Immutable transaction values and revision captured at batch cutoff.
final class BackupTransactionRecord extends Equatable {
  const BackupTransactionRecord({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amountPiasters,
    required this.note,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.localRevision,
  }) : assert(amountPiasters > 0),
       assert(localRevision >= 1);

  final String id;
  final String customerId;
  final TransactionType type;
  final int amountPiasters;
  final String? note;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int localRevision;

  bool get isDeleted => deletedAt != null;

  @override
  List<Object?> get props => [
    id,
    customerId,
    type,
    amountPiasters,
    note,
    transactionDate,
    createdAt,
    updatedAt,
    deletedAt,
    localRevision,
  ];
}

/// Immutable append-only transaction audit log captured at batch cutoff.
final class BackupAuditLogRecord extends Equatable {
  const BackupAuditLogRecord({
    required this.id,
    required this.transactionId,
    required this.action,
    required this.previousType,
    required this.previousAmountPiasters,
    required this.previousNote,
    required this.previousTransactionDate,
    required this.createdAt,
    required this.localRevision,
  }) : assert(previousAmountPiasters > 0),
       assert(localRevision >= 1);

  final String id;
  final String transactionId;
  final BackupAuditAction action;
  final TransactionType previousType;
  final int previousAmountPiasters;
  final String? previousNote;
  final DateTime previousTransactionDate;
  final DateTime createdAt;
  final int localRevision;

  @override
  List<Object?> get props => [
    id,
    transactionId,
    action,
    previousType,
    previousAmountPiasters,
    previousNote,
    previousTransactionDate,
    createdAt,
    localRevision,
  ];
}

/// Atomic cutoff snapshot of pending ledger records and their captured
/// revisions for a single backup publication attempt.
final class BackupBatch extends Equatable {
  BackupBatch({
    required this.batchId,
    required this.ownerUserId,
    required this.deviceId,
    required DateTime capturedAt,
    required List<BackupCustomerRecord> customers,
    required List<BackupTransactionRecord> transactions,
    required List<BackupAuditLogRecord> auditLogs,
  }) : capturedAt = capturedAt.toUtc(),
       customers = List.unmodifiable(customers),
       transactions = List.unmodifiable(transactions),
       auditLogs = List.unmodifiable(auditLogs);

  final String batchId;
  final String ownerUserId;
  final String deviceId;
  final DateTime capturedAt;
  final List<BackupCustomerRecord> customers;
  final List<BackupTransactionRecord> transactions;
  final List<BackupAuditLogRecord> auditLogs;

  int get totalRecords =>
      customers.length + transactions.length + auditLogs.length;

  bool get isEmpty => totalRecords == 0;

  bool get isNotEmpty => !isEmpty;

  BackupBatchAcknowledgment toAcknowledgment({required DateTime confirmedAt}) =>
      BackupBatchAcknowledgment(
        batchId: batchId,
        ownerUserId: ownerUserId,
        deviceId: deviceId,
        confirmedAt: confirmedAt,
        customerRevisions: {
          for (final record in customers) record.id: record.localRevision,
        },
        transactionRevisions: {
          for (final record in transactions) record.id: record.localRevision,
        },
        auditLogRevisions: {
          for (final record in auditLogs) record.id: record.localRevision,
        },
      );

  @override
  List<Object?> get props => [
    batchId,
    ownerUserId,
    deviceId,
    capturedAt,
    customers,
    transactions,
    auditLogs,
  ];
}

/// Exact revisions captured in a confirmed [BackupBatch] that may be
/// acknowledged locally after server publication succeeds.
final class BackupBatchAcknowledgment extends Equatable {
  BackupBatchAcknowledgment({
    required this.batchId,
    required this.ownerUserId,
    required this.deviceId,
    required DateTime confirmedAt,
    required Map<String, int> customerRevisions,
    required Map<String, int> transactionRevisions,
    required Map<String, int> auditLogRevisions,
  }) : confirmedAt = confirmedAt.toUtc(),
       customerRevisions = Map.unmodifiable(customerRevisions),
       transactionRevisions = Map.unmodifiable(transactionRevisions),
       auditLogRevisions = Map.unmodifiable(auditLogRevisions);

  final String batchId;
  final String ownerUserId;
  final String deviceId;
  final DateTime confirmedAt;
  final Map<String, int> customerRevisions;
  final Map<String, int> transactionRevisions;
  final Map<String, int> auditLogRevisions;

  int get totalRecords =>
      customerRevisions.length +
      transactionRevisions.length +
      auditLogRevisions.length;

  @override
  List<Object?> get props => [
    batchId,
    ownerUserId,
    deviceId,
    confirmedAt,
    customerRevisions,
    transactionRevisions,
    auditLogRevisions,
  ];
}

/// Outcome of applying a confirmed [BackupBatchAcknowledgment] locally.
final class BackupAcknowledgmentSummary extends Equatable {
  BackupAcknowledgmentSummary({
    required this.acknowledgedRecordCount,
    required this.remainingPendingCount,
    required DateTime confirmedAt,
  }) : assert(acknowledgedRecordCount >= 0),
       assert(remainingPendingCount >= 0),
       confirmedAt = confirmedAt.toUtc();

  final int acknowledgedRecordCount;
  final int remainingPendingCount;
  final DateTime confirmedAt;

  bool get hasRemainingPendingChanges => remainingPendingCount > 0;

  @override
  List<Object> get props => [
    acknowledgedRecordCount,
    remainingPendingCount,
    confirmedAt,
  ];
}

/// Atomic outcome of attempting to acknowledge a confirmed batch locally.
sealed class BackupAcknowledgmentResult extends Equatable {
  const BackupAcknowledgmentResult();

  @override
  List<Object?> get props => [];
}

final class BackupAcknowledgmentApplied extends BackupAcknowledgmentResult {
  const BackupAcknowledgmentApplied({
    required this.summary,
    required this.scheduleState,
  });

  final BackupAcknowledgmentSummary summary;
  final BackupScheduleState scheduleState;

  @override
  List<Object?> get props => [summary, scheduleState];
}

/// Returned when live session or device-authority verification fails at commit
/// time, leaving revisions, in-flight batch and schedule metadata untouched.
final class BackupAcknowledgmentBlocked extends BackupAcknowledgmentResult {
  const BackupAcknowledgmentBlocked({
    required this.reason,
    required this.scheduleState,
  });

  final BackupIneligibilityReason reason;
  final BackupScheduleState scheduleState;

  @override
  List<Object?> get props => [reason, scheduleState];
}
