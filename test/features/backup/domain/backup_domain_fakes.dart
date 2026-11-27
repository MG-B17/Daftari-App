import 'dart:async';

import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/services/date/date_service.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_batch.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_eligibility.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_run_result.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_schedule.dart';
import 'package:daftariapp/features/backup/domain/policies/backup_cutoff_policy.dart';
import 'package:daftariapp/features/backup/domain/repositories/backup_cloud_publisher.dart';
import 'package:daftariapp/features/backup/domain/repositories/backup_local_store.dart';
import 'package:daftariapp/features/backup/domain/repositories/backup_run_lock.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
import 'package:fpdart/fpdart.dart';

class FakeDateService implements DateService {
  FakeDateService(this.current);

  DateTime current;

  @override
  DateTime now() => current;
}

class InMemoryBackupRunLock implements BackupRunLock {
  bool _locked = false;
  int acquireAttempts = 0;
  int releaseCount = 0;

  @override
  bool get isLocked => _locked;

  @override
  Future<BackupRunLease?> tryAcquire() async {
    acquireAttempts++;
    if (_locked) return null;
    _locked = true;
    return _InMemoryLease(() {
      _locked = false;
      releaseCount++;
    });
  }
}

class _InMemoryLease implements BackupRunLease {
  _InMemoryLease(this._onRelease);

  final void Function() _onRelease;
  bool _released = false;

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    _onRelease();
  }
}

class FakeBackupLocalStore implements BackupLocalStore {
  FakeBackupLocalStore({
    this.authenticatedUserId = 'user-a',
    this.isEmailVerified = true,
    this.linkedOwnerUserId = 'user-a',
    this.deviceId = 'device-1',
    this.isActiveDevice = true,
    this.hasConnectivity = true,
    this.scheduleState = const BackupScheduleState.initial(),
    this.runLockForRunningFlag,
  });

  String? authenticatedUserId;
  bool isEmailVerified;
  String? linkedOwnerUserId;
  String? deviceId;
  bool isActiveDevice;
  bool hasConnectivity;
  BackupScheduleState scheduleState;
  BackupRunLock? runLockForRunningFlag;
  BackupBatch? inFlightBatch;

  final Map<String, BackupCustomerRecord> customers = {};
  final Map<String, int> customerAckRevisions = {};

  final Map<String, BackupTransactionRecord> transactions = {};
  final Map<String, int> transactionAckRevisions = {};

  final Map<String, BackupAuditLogRecord> auditLogs = {};
  final Map<String, int> auditLogAckRevisions = {};

  AppFailure? readScheduleFailure;
  AppFailure? updateScheduleFailure;
  AppFailure? captureFailure;
  AppFailure? acknowledgeFailure;
  AppFailure? markDeviceInactiveFailure;
  bool forceEmptyCaptureOnce = false;

  Future<void> Function()? beforeScheduleUpdateCommit;
  Future<void> Function()? beforeAcknowledgeCommit;

  int captureCalls = 0;
  int acknowledgeCalls = 0;
  int scheduleWriteCount = 0;
  int markDeviceInactiveCalls = 0;

  void putCustomer(
    BackupCustomerRecord record, {
    int acknowledgedRevision = 0,
  }) {
    customers[record.id] = record;
    customerAckRevisions[record.id] = acknowledgedRevision;
  }

  void putTransaction(
    BackupTransactionRecord record, {
    int acknowledgedRevision = 0,
  }) {
    transactions[record.id] = record;
    transactionAckRevisions[record.id] = acknowledgedRevision;
  }

  void putAuditLog(
    BackupAuditLogRecord record, {
    int acknowledgedRevision = 0,
  }) {
    auditLogs[record.id] = record;
    auditLogAckRevisions[record.id] = acknowledgedRevision;
  }

  /// Simulates an atomic local transaction edit + append-only edit audit log.
  void editTransactionLocally({
    required String transactionId,
    required int newAmountPiasters,
    required String auditId,
    required DateTime editedAt,
    String? newNote,
  }) {
    final current = transactions[transactionId]!;
    auditLogs[auditId] = BackupAuditLogRecord(
      id: auditId,
      transactionId: current.id,
      action: BackupAuditAction.edit,
      previousType: current.type,
      previousAmountPiasters: current.amountPiasters,
      previousNote: current.note,
      previousTransactionDate: current.transactionDate,
      createdAt: editedAt,
      localRevision: 1,
    );
    auditLogAckRevisions[auditId] = 0;

    transactions[transactionId] = BackupTransactionRecord(
      id: current.id,
      customerId: current.customerId,
      type: current.type,
      amountPiasters: newAmountPiasters,
      note: newNote ?? current.note,
      transactionDate: current.transactionDate,
      createdAt: current.createdAt,
      updatedAt: editedAt,
      deletedAt: current.deletedAt,
      localRevision: current.localRevision + 1,
    );
  }

  /// Simulates an atomic local soft-delete + append-only delete audit log.
  void softDeleteTransactionLocally({
    required String transactionId,
    required String auditId,
    required DateTime deletedAt,
  }) {
    final current = transactions[transactionId]!;
    auditLogs[auditId] = BackupAuditLogRecord(
      id: auditId,
      transactionId: current.id,
      action: BackupAuditAction.delete,
      previousType: current.type,
      previousAmountPiasters: current.amountPiasters,
      previousNote: current.note,
      previousTransactionDate: current.transactionDate,
      createdAt: deletedAt,
      localRevision: 1,
    );
    auditLogAckRevisions[auditId] = 0;

    transactions[transactionId] = BackupTransactionRecord(
      id: current.id,
      customerId: current.customerId,
      type: current.type,
      amountPiasters: current.amountPiasters,
      note: current.note,
      transactionDate: current.transactionDate,
      createdAt: current.createdAt,
      updatedAt: deletedAt,
      deletedAt: deletedAt,
      localRevision: current.localRevision + 1,
    );
  }

  int countPendingChanges() {
    var count = 0;
    for (final customer in customers.values) {
      if (BackupCutoffPolicy.isRecordPending(
        localRevision: customer.localRevision,
        acknowledgedRevision: customerAckRevisions[customer.id] ?? 0,
      )) {
        count++;
      }
    }
    for (final tx in transactions.values) {
      if (BackupCutoffPolicy.isRecordPending(
        localRevision: tx.localRevision,
        acknowledgedRevision: transactionAckRevisions[tx.id] ?? 0,
      )) {
        count++;
      }
    }
    for (final audit in auditLogs.values) {
      if (BackupCutoffPolicy.isRecordPending(
        localRevision: audit.localRevision,
        acknowledgedRevision: auditLogAckRevisions[audit.id] ?? 0,
      )) {
        count++;
      }
    }
    return count;
  }

  BackupEligibilityContext _currentContext() => BackupEligibilityContext(
    authenticatedUserId: authenticatedUserId,
    isEmailVerified: isEmailVerified,
    linkedOwnerUserId: linkedOwnerUserId,
    deviceId: deviceId,
    isActiveDevice: isActiveDevice,
    pendingChangesCount: countPendingChanges(),
    hasConnectivity: hasConnectivity,
    isBackupRunning: runLockForRunningFlag?.isLocked ?? false,
  );

  @override
  Future<Either<AppFailure, BackupEligibilityContext>>
  readEligibilityContext() async => Right(_currentContext());

  @override
  Future<Either<AppFailure, BackupScheduleState>> readScheduleState() async {
    if (readScheduleFailure case final failure?) return Left(failure);
    return Right(scheduleState);
  }

  @override
  Future<Either<AppFailure, BackupScheduleState>> updateScheduleState(
    BackupScheduleState Function(
      BackupScheduleState latest,
      bool hasPendingChanges,
    )
    transform,
  ) async {
    if (beforeScheduleUpdateCommit case final hook?) {
      await hook();
    }
    if (updateScheduleFailure case final failure?) return Left(failure);
    // Atomic read-transform-write against the latest persisted state.
    final next = transform(scheduleState, countPendingChanges() > 0);
    if (next != scheduleState) {
      scheduleState = next;
      scheduleWriteCount++;
    }
    return Right(scheduleState);
  }

  @override
  Future<Either<AppFailure, BackupBatch?>> readInFlightBatch() async =>
      Right(inFlightBatch);

  @override
  Future<Either<AppFailure, BackupBatch>> capturePendingBatch({
    required String batchId,
    required String ownerUserId,
    required String deviceId,
    required DateTime capturedAt,
  }) async {
    captureCalls++;
    if (captureFailure case final failure?) return Left(failure);
    if (forceEmptyCaptureOnce) {
      forceEmptyCaptureOnce = false;
      return Right(
        BackupBatch(
          batchId: batchId,
          ownerUserId: ownerUserId,
          deviceId: deviceId,
          capturedAt: capturedAt,
          customers: const [],
          transactions: const [],
          auditLogs: const [],
        ),
      );
    }

    final pendingCustomers = customers.values
        .where(
          (c) => BackupCutoffPolicy.isRecordPending(
            localRevision: c.localRevision,
            acknowledgedRevision: customerAckRevisions[c.id] ?? 0,
          ),
        )
        .toList();
    final pendingTransactions = transactions.values
        .where(
          (t) => BackupCutoffPolicy.isRecordPending(
            localRevision: t.localRevision,
            acknowledgedRevision: transactionAckRevisions[t.id] ?? 0,
          ),
        )
        .toList();
    final pendingAudits = auditLogs.values
        .where(
          (a) => BackupCutoffPolicy.isRecordPending(
            localRevision: a.localRevision,
            acknowledgedRevision: auditLogAckRevisions[a.id] ?? 0,
          ),
        )
        .toList();

    final batch = BackupBatch(
      batchId: batchId,
      ownerUserId: ownerUserId,
      deviceId: deviceId,
      capturedAt: capturedAt,
      customers: pendingCustomers,
      transactions: pendingTransactions,
      auditLogs: pendingAudits,
    );
    if (batch.isNotEmpty) {
      inFlightBatch = batch;
    }
    return Right(batch);
  }

  @override
  Future<Either<AppFailure, BackupAcknowledgmentResult>> acknowledgeBatch(
    BackupBatchAcknowledgment acknowledgment, {
    required BackupScheduleState Function(BackupScheduleState latest)
    updateSchedule,
  }) async {
    if (beforeAcknowledgeCommit case final hook?) {
      await hook();
    }
    acknowledgeCalls++;
    if (acknowledgeFailure case final failure?) return Left(failure);

    // Conditional commit-time verification of live session and device authority.
    final blockReason = BackupCutoffPolicy.acknowledgmentBlockReason(
      batchOwnerUserId: acknowledgment.ownerUserId,
      batchDeviceId: acknowledgment.deviceId,
      currentContext: _currentContext(),
    );
    if (blockReason != null) {
      return Right(
        BackupAcknowledgmentBlocked(
          reason: blockReason,
          scheduleState: scheduleState,
        ),
      );
    }

    var fullyAcknowledged = 0;
    for (final entry in acknowledgment.customerRevisions.entries) {
      final current = customers[entry.key]!;
      final nextAck = BackupCutoffPolicy.resolveAcknowledgedRevision(
        localRevision: current.localRevision,
        currentAcknowledgedRevision: customerAckRevisions[entry.key] ?? 0,
        capturedRevision: entry.value,
      );
      customerAckRevisions[entry.key] = nextAck;
      if (!BackupCutoffPolicy.isRecordPending(
        localRevision: current.localRevision,
        acknowledgedRevision: nextAck,
      )) {
        fullyAcknowledged++;
      }
    }
    for (final entry in acknowledgment.transactionRevisions.entries) {
      final current = transactions[entry.key]!;
      final nextAck = BackupCutoffPolicy.resolveAcknowledgedRevision(
        localRevision: current.localRevision,
        currentAcknowledgedRevision: transactionAckRevisions[entry.key] ?? 0,
        capturedRevision: entry.value,
      );
      transactionAckRevisions[entry.key] = nextAck;
      if (!BackupCutoffPolicy.isRecordPending(
        localRevision: current.localRevision,
        acknowledgedRevision: nextAck,
      )) {
        fullyAcknowledged++;
      }
    }
    for (final entry in acknowledgment.auditLogRevisions.entries) {
      final current = auditLogs[entry.key]!;
      final nextAck = BackupCutoffPolicy.resolveAcknowledgedRevision(
        localRevision: current.localRevision,
        currentAcknowledgedRevision: auditLogAckRevisions[entry.key] ?? 0,
        capturedRevision: entry.value,
      );
      auditLogAckRevisions[entry.key] = nextAck;
      if (!BackupCutoffPolicy.isRecordPending(
        localRevision: current.localRevision,
        acknowledgedRevision: nextAck,
      )) {
        fullyAcknowledged++;
      }
    }

    if (inFlightBatch?.batchId == acknowledgment.batchId) {
      inFlightBatch = null;
    }

    final updatedSchedule = updateSchedule(scheduleState);
    if (updatedSchedule != scheduleState) {
      scheduleState = updatedSchedule;
      scheduleWriteCount++;
    }

    return Right(
      BackupAcknowledgmentApplied(
        summary: BackupAcknowledgmentSummary(
          acknowledgedRecordCount: fullyAcknowledged,
          remainingPendingCount: countPendingChanges(),
          confirmedAt: acknowledgment.confirmedAt,
        ),
        scheduleState: scheduleState,
      ),
    );
  }

  @override
  Future<Either<AppFailure, void>> markDeviceInactive() async {
    markDeviceInactiveCalls++;
    if (markDeviceInactiveFailure case final failure?) return Left(failure);
    isActiveDevice = false;
    return const Right(null);
  }
}

class FakeBackupCloudPublisher implements BackupCloudPublisher {
  FakeBackupCloudPublisher({required DateTime serverTime})
    : serverTime = serverTime.toUtc();

  DateTime serverTime;
  final List<BackupBatch> publishedBatches = [];
  final Map<String, DateTime> confirmedBatchesById = {};
  final Map<String, BackupCustomerRecord> cloudCustomers = {};
  final Map<String, BackupTransactionRecord> cloudTransactions = {};
  final Map<String, BackupAuditLogRecord> cloudAuditLogs = {};

  AppFailure? nextFailure;
  bool rejectAsInactiveDevice = false;
  Future<void> Function(BackupBatch batch)? onPublishStarted;

  int get publishAttempts => _publishAttempts;
  int _publishAttempts = 0;

  int get findConfirmationCalls => _findConfirmationCalls;
  int _findConfirmationCalls = 0;

  int get distinctServerCommits => confirmedBatchesById.length;

  @override
  Future<Either<AppFailure, BackupPublicationResult?>> findBatchConfirmation({
    required String batchId,
    required String ownerUserId,
    required String deviceId,
  }) async {
    _findConfirmationCalls++;
    if (nextFailure case final failure?) return Left(failure);
    if (rejectAsInactiveDevice) {
      return const Right(BackupPublicationInactiveDevice());
    }
    final confirmedAt = confirmedBatchesById[batchId];
    if (confirmedAt == null) return const Right(null);
    return Right(
      BackupPublicationConfirmed(batchId: batchId, confirmedAt: confirmedAt),
    );
  }

  @override
  Future<Either<AppFailure, BackupPublicationResult>> publishBatch(
    BackupBatch batch,
  ) async {
    _publishAttempts++;
    if (onPublishStarted case final hook?) {
      await hook(batch);
    }
    if (nextFailure case final failure?) {
      return Left(failure);
    }
    if (rejectAsInactiveDevice) {
      return const Right(BackupPublicationInactiveDevice());
    }

    // Idempotent server commit keyed by batchId.
    if (confirmedBatchesById[batch.batchId] case final existingConfirmedAt?) {
      return Right(
        BackupPublicationConfirmed(
          batchId: batch.batchId,
          confirmedAt: existingConfirmedAt,
        ),
      );
    }

    publishedBatches.add(batch);
    confirmedBatchesById[batch.batchId] = serverTime;
    for (final customer in batch.customers) {
      cloudCustomers[customer.id] = customer;
    }
    for (final tx in batch.transactions) {
      cloudTransactions[tx.id] = tx;
    }
    for (final audit in batch.auditLogs) {
      cloudAuditLogs[audit.id] = audit;
    }
    return Right(
      BackupPublicationConfirmed(
        batchId: batch.batchId,
        confirmedAt: serverTime,
      ),
    );
  }
}

BackupCustomerRecord testCustomer({
  String id = 'cust-1',
  String name = 'Ahmed',
  int localRevision = 1,
  DateTime? timestamp,
  DateTime? deletedAt,
}) {
  final ts = timestamp ?? DateTime.utc(2026, 11, 20, 8);
  return BackupCustomerRecord(
    id: id,
    name: name,
    phone: '01000000000',
    notes: null,
    createdAt: ts,
    updatedAt: ts,
    deletedAt: deletedAt,
    localRevision: localRevision,
  );
}

BackupTransactionRecord testTransaction({
  String id = 'tx-1',
  String customerId = 'cust-1',
  TransactionType type = TransactionType.credit,
  int amountPiasters = 10000,
  String? note,
  int localRevision = 1,
  DateTime? timestamp,
  DateTime? deletedAt,
}) {
  final ts = timestamp ?? DateTime.utc(2026, 11, 20, 9);
  return BackupTransactionRecord(
    id: id,
    customerId: customerId,
    type: type,
    amountPiasters: amountPiasters,
    note: note,
    transactionDate: ts,
    createdAt: ts,
    updatedAt: ts,
    deletedAt: deletedAt,
    localRevision: localRevision,
  );
}
