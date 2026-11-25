import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';

import '../../errors/app_exception.dart';
import '../app_database.dart';
import 'dao_support.dart';

part 'backup_dao.g.dart';

/// Internal sentinel thrown inside [BackupDao.acknowledgeBatch]'s SQLite
/// transaction when the synchronous pre-commit authority check fails so Drift
/// rolls back every write before committing.
final class _AcknowledgmentRollbackSignal implements Exception {
  const _AcknowledgmentRollbackSignal();
}

/// Immutable snapshot of the single-row `backup_metadata` table.
final class BackupMetadataSnapshot extends Equatable {
  const BackupMetadataSnapshot({
    required this.schedule,
    required this.lastConfirmedAtIso,
    required this.nextDueAtIso,
    required this.isDeviceActive,
  });

  const BackupMetadataSnapshot.initial()
    : schedule = null,
      lastConfirmedAtIso = null,
      nextDueAtIso = null,
      isDeviceActive = true;

  final String? schedule;
  final String? lastConfirmedAtIso;
  final String? nextDueAtIso;
  final bool isDeviceActive;

  BackupMetadataSnapshot copyWith({
    String? Function()? schedule,
    String? Function()? lastConfirmedAtIso,
    String? Function()? nextDueAtIso,
    bool? isDeviceActive,
  }) => BackupMetadataSnapshot(
    schedule: schedule != null ? schedule() : this.schedule,
    lastConfirmedAtIso: lastConfirmedAtIso != null
        ? lastConfirmedAtIso()
        : this.lastConfirmedAtIso,
    nextDueAtIso: nextDueAtIso != null ? nextDueAtIso() : this.nextDueAtIso,
    isDeviceActive: isDeviceActive ?? this.isDeviceActive,
  );

  @override
  List<Object?> get props => [
    schedule,
    lastConfirmedAtIso,
    nextDueAtIso,
    isDeviceActive,
  ];
}

/// Consistent local backup status read inside a single SQLite transaction.
final class BackupLocalStatusSnapshot extends Equatable {
  const BackupLocalStatusSnapshot({
    required this.isDeviceActive,
    required this.pendingChangesCount,
  });

  final bool isDeviceActive;
  final int pendingChangesCount;

  @override
  List<Object?> get props => [isDeviceActive, pendingChangesCount];
}

/// Consistent local ledger counts and deterministic revision stamp read inside
/// a single SQLite transaction for cloud restore preview and pre-replacement
/// verification.
final class RestoreLedgerCountsSnapshot extends Equatable {
  const RestoreLedgerCountsSnapshot({
    required this.customerCount,
    required this.deletedCustomerCount,
    required this.transactionCount,
    required this.deletedTransactionCount,
    required this.auditLogCount,
    required this.pendingChangesCount,
    required this.isDeviceActive,
    required this.revisionStamp,
  });

  final int customerCount;
  final int deletedCustomerCount;
  final int transactionCount;
  final int deletedTransactionCount;
  final int auditLogCount;
  final int pendingChangesCount;
  final bool isDeviceActive;
  final String revisionStamp;

  int get totalRecordCount =>
      customerCount +
      deletedCustomerCount +
      transactionCount +
      deletedTransactionCount +
      auditLogCount;

  bool get isPopulated => totalRecordCount > 0;

  @override
  List<Object?> get props => [
    customerCount,
    deletedCustomerCount,
    transactionCount,
    deletedTransactionCount,
    auditLogCount,
    pendingChangesCount,
    isDeviceActive,
    revisionStamp,
  ];
}

/// Pending ledger rows captured atomically at batch cutoff.
final class BackupPendingRecordsSnapshot {
  const BackupPendingRecordsSnapshot({
    required this.customers,
    required this.transactions,
    required this.auditLogs,
  });

  final List<Customer> customers;
  final List<TransactionRecord> transactions;
  final List<TransactionAuditLog> auditLogs;

  bool get isEmpty =>
      customers.isEmpty && transactions.isEmpty && auditLogs.isEmpty;
}

/// Outcome of committing a batch acknowledgment inside a SQLite transaction.
final class BackupAcknowledgmentCommitOutcome extends Equatable {
  const BackupAcknowledgmentCommitOutcome({
    required this.acknowledgedRecordCount,
    required this.remainingPendingCount,
    required this.metadata,
  });

  final int acknowledgedRecordCount;
  final int remainingPendingCount;
  final BackupMetadataSnapshot metadata;

  @override
  List<Object?> get props => [
    acknowledgedRecordCount,
    remainingPendingCount,
    metadata,
  ];
}

/// Transactional local persistence for cloud backup capture, durable in-flight
/// batch recovery, installation identity arbitration, schedule metadata, and
/// revision-checked acknowledgment.
@DriftAccessor(
  tables: [
    Customers,
    Transactions,
    TransactionAuditLogs,
    BackupMetadata,
    BackupInFlightBatches,
    BackupDeviceIdentities,
  ],
)
class BackupDao extends DatabaseAccessor<AppDatabase> with _$BackupDaoMixin {
  BackupDao(super.db);

  static const _singletonRowId = 1;

  Future<String?> readDeviceId() => runDatabaseOperation(() async {
    final row = await (select(
      backupDeviceIdentities,
    )..where((r) => r.id.equals(_singletonRowId))).getSingleOrNull();
    return row?.deviceId;
  });

  /// Atomically claims [candidateDeviceId] if no device identity exists yet,
  /// returning the canonical persisted device ID.
  ///
  /// Uses `INSERT OR IGNORE` inside a SQLite transaction so concurrent
  /// foreground and worker instances always converge on one winning ID.
  Future<String> claimOrReadDeviceId(String candidateDeviceId) =>
      runDatabaseOperation(
        () => transaction(() async {
          final trimmed = candidateDeviceId.trim();
          if (trimmed.isEmpty) throw const ValidationException();
          await into(backupDeviceIdentities).insert(
            BackupDeviceIdentitiesCompanion(
              id: const Value(_singletonRowId),
              deviceId: Value(trimmed),
            ),
            mode: InsertMode.insertOrIgnore,
          );
          final winner = await (select(
            backupDeviceIdentities,
          )..where((r) => r.id.equals(_singletonRowId))).getSingle();
          return winner.deviceId;
        }),
      );

  Future<BackupMetadataSnapshot> readMetadata() =>
      runDatabaseOperation(_readMetadata);

  Stream<BackupMetadataSnapshot> watchMetadata() =>
      (select(
        backupMetadata,
      )..where((r) => r.id.equals(_singletonRowId))).watchSingleOrNull().map(
        (row) => row == null
            ? const BackupMetadataSnapshot.initial()
            : BackupMetadataSnapshot(
                schedule: row.schedule,
                lastConfirmedAtIso: row.lastConfirmedAtIso,
                nextDueAtIso: row.nextDueAtIso,
                isDeviceActive: row.isDeviceActive,
              ),
      );

  Stream<int> watchPendingChangesCount() => customSelect(
    'SELECT '
    '(SELECT COUNT(*) FROM customers WHERE local_revision > acknowledged_revision) + '
    '(SELECT COUNT(*) FROM transactions WHERE local_revision > acknowledged_revision) + '
    '(SELECT COUNT(*) FROM transaction_audit_logs WHERE local_revision > acknowledged_revision) '
    'AS pending_count',
    readsFrom: {customers, transactions, transactionAuditLogs},
  ).watchSingle().map((row) => row.read<int>('pending_count'));

  Future<BackupLocalStatusSnapshot> readLocalStatus() => runDatabaseOperation(
    () => transaction(() async {
      final metadata = await _readMetadata();
      final pendingChangesCount = await _countPendingChanges();
      return BackupLocalStatusSnapshot(
        isDeviceActive: metadata.isDeviceActive,
        pendingChangesCount: pendingChangesCount,
      );
    }),
  );

  Future<int> countPendingChanges() =>
      runDatabaseOperation(_countPendingChanges);

  Future<BackupMetadataSnapshot> updateScheduleMetadata(
    BackupMetadataSnapshot Function(
      BackupMetadataSnapshot latest,
      bool hasPendingChanges,
    )
    transform,
  ) => runDatabaseOperation(
    () => transaction(() async {
      final latest = await _readMetadata();
      final hasPendingChanges = (await _countPendingChanges()) > 0;
      final next = transform(latest, hasPendingChanges);
      if (next != latest) {
        await _writeMetadata(next);
      }
      return next;
    }),
  );

  Future<BackupInFlightBatchRow?> readInFlightBatch() => runDatabaseOperation(
    () => (select(
      backupInFlightBatches,
    )..where((row) => row.id.equals(_singletonRowId))).getSingleOrNull(),
  );

  /// Atomically captures all pending customers, transactions (including
  /// soft-deletion tombstones) and audit logs, persisting [encodePayload] as
  /// the durable in-flight batch when non-empty.
  Future<BackupPendingRecordsSnapshot> capturePendingBatch({
    required String batchId,
    required String ownerUserId,
    required String deviceId,
    required String capturedAtIso,
    required String Function(BackupPendingRecordsSnapshot snapshot)
    encodePayload,
  }) => runDatabaseOperation(
    () => transaction(() async {
      final existing = await (select(
        backupInFlightBatches,
      )..where((row) => row.id.equals(_singletonRowId))).getSingleOrNull();
      if (existing != null) {
        throw const DatabaseException();
      }

      final pendingCustomers =
          await (select(customers)
                ..where(
                  (row) =>
                      row.localRevision.isBiggerThan(row.acknowledgedRevision),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.id)]))
              .get();

      final pendingTransactions =
          await (select(transactions)
                ..where(
                  (row) =>
                      row.localRevision.isBiggerThan(row.acknowledgedRevision),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.id)]))
              .get();

      final pendingAuditLogs =
          await (select(transactionAuditLogs)
                ..where(
                  (row) =>
                      row.localRevision.isBiggerThan(row.acknowledgedRevision),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.id)]))
              .get();

      final snapshot = BackupPendingRecordsSnapshot(
        customers: pendingCustomers,
        transactions: pendingTransactions,
        auditLogs: pendingAuditLogs,
      );

      if (!snapshot.isEmpty) {
        final payloadJson = encodePayload(snapshot);
        await into(backupInFlightBatches).insert(
          BackupInFlightBatchesCompanion(
            id: const Value(_singletonRowId),
            batchId: Value(batchId),
            ownerUserId: Value(ownerUserId),
            deviceId: Value(deviceId),
            capturedAtIso: Value(capturedAtIso),
            payloadJson: Value(payloadJson),
          ),
        );
      }

      return snapshot;
    }),
  );

  /// Atomically verifies commit-time authority via [verifyCommitAllowed] before
  /// mutating rows, applies monotonic revision acknowledgments, clears the
  /// matching in-flight batch and updates persisted schedule metadata, then
  /// re-verifies authority synchronously via [verifyBeforeCommit] right before
  /// SQLite commits.
  ///
  /// When either guard returns `false`, rolls back any writes and returns
  /// `null` without mutating any persisted table.
  Future<BackupAcknowledgmentCommitOutcome?> acknowledgeBatch({
    required String batchId,
    required DateTime confirmedAt,
    required Map<String, int> customerRevisions,
    required Map<String, int> transactionRevisions,
    required Map<String, int> auditLogRevisions,
    required Future<bool> Function(BackupMetadataSnapshot latest)
    verifyCommitAllowed,
    required bool Function() verifyBeforeCommit,
    void Function()? onEnterCommit,
    void Function()? onExitCommit,
    Future<bool> Function()? tryEnterCommit,
    Future<void> Function()? onExitCommitAsync,
    required BackupMetadataSnapshot Function(BackupMetadataSnapshot latest)
    updateSchedule,
    required int Function({
      required int localRevision,
      required int currentAcknowledgedRevision,
      required int capturedRevision,
    })
    resolveRevision,
  }) => runDatabaseOperation(() async {
    var commitEntered = false;
    try {
      return await transaction(() async {
        final latest = await _readMetadata();
        final allowed = await verifyCommitAllowed(latest);
        if (!allowed) return null;

        final confirmedUtc = confirmedAt.toUtc();
        var fullyAcknowledged = 0;

        for (final entry in customerRevisions.entries) {
          final current = await (select(
            customers,
          )..where((row) => row.id.equals(entry.key))).getSingleOrNull();
          if (current == null) throw const DatabaseException();
          final nextAck = resolveRevision(
            localRevision: current.localRevision,
            currentAcknowledgedRevision: current.acknowledgedRevision,
            capturedRevision: entry.value,
          );
          if (nextAck != current.acknowledgedRevision ||
              current.syncedAt == null) {
            await (update(
              customers,
            )..where((row) => row.id.equals(entry.key))).write(
              CustomersCompanion(
                acknowledgedRevision: Value(nextAck),
                syncedAt: Value(confirmedUtc),
              ),
            );
          }
          if (current.localRevision <= nextAck) {
            fullyAcknowledged++;
          }
        }

        for (final entry in transactionRevisions.entries) {
          final current = await (select(
            transactions,
          )..where((row) => row.id.equals(entry.key))).getSingleOrNull();
          if (current == null) throw const DatabaseException();
          final nextAck = resolveRevision(
            localRevision: current.localRevision,
            currentAcknowledgedRevision: current.acknowledgedRevision,
            capturedRevision: entry.value,
          );
          if (nextAck != current.acknowledgedRevision ||
              current.syncedAt == null) {
            await (update(
              transactions,
            )..where((row) => row.id.equals(entry.key))).write(
              TransactionsCompanion(
                acknowledgedRevision: Value(nextAck),
                syncedAt: Value(confirmedUtc),
              ),
            );
          }
          if (current.localRevision <= nextAck) {
            fullyAcknowledged++;
          }
        }

        for (final entry in auditLogRevisions.entries) {
          final current = await (select(
            transactionAuditLogs,
          )..where((row) => row.id.equals(entry.key))).getSingleOrNull();
          if (current == null) throw const DatabaseException();
          final nextAck = resolveRevision(
            localRevision: current.localRevision,
            currentAcknowledgedRevision: current.acknowledgedRevision,
            capturedRevision: entry.value,
          );
          if (nextAck != current.acknowledgedRevision ||
              current.syncedAt == null) {
            await (update(
              transactionAuditLogs,
            )..where((row) => row.id.equals(entry.key))).write(
              TransactionAuditLogsCompanion(
                acknowledgedRevision: Value(nextAck),
                syncedAt: Value(confirmedUtc),
              ),
            );
          }
          if (current.localRevision <= nextAck) {
            fullyAcknowledged++;
          }
        }

        await (delete(backupInFlightBatches)..where(
              (row) =>
                  row.id.equals(_singletonRowId) & row.batchId.equals(batchId),
            ))
            .go();

        final nextMetadata = updateSchedule(latest);
        if (nextMetadata != latest) {
          await _writeMetadata(nextMetadata);
        }

        final remainingPendingCount = await _countPendingChanges();

        if (!verifyBeforeCommit()) {
          throw const _AcknowledgmentRollbackSignal();
        }
        if (tryEnterCommit != null) {
          final entered = await tryEnterCommit();
          if (!entered) {
            throw const _AcknowledgmentRollbackSignal();
          }
          commitEntered = true;
        } else {
          onEnterCommit?.call();
          commitEntered = true;
        }

        return BackupAcknowledgmentCommitOutcome(
          acknowledgedRecordCount: fullyAcknowledged,
          remainingPendingCount: remainingPendingCount,
          metadata: nextMetadata,
        );
      });
    } on _AcknowledgmentRollbackSignal {
      return null;
    } finally {
      if (commitEntered) {
        onExitCommit?.call();
        if (onExitCommitAsync != null) {
          await onExitCommitAsync();
        }
      }
    }
  });

  Future<void> markDeviceInactive() => runDatabaseOperation(
    () => transaction(() async {
      final latest = await _readMetadata();
      if (latest.isDeviceActive) {
        await _writeMetadata(latest.copyWith(isDeviceActive: false));
      }
    }),
  );

  /// Reads all active and soft-deleted customer/transaction counts, audit log
  /// count, pending changes count, device active flag, and a deterministic
  /// revision stamp inside a single SQLite transaction.
  Future<RestoreLedgerCountsSnapshot> readRestoreLedgerCounts() =>
      runDatabaseOperation(
        () => transaction(() async {
          final metadata = await _readMetadata();
          return _readRestoreLedgerCountsInternal(
            isDeviceActive: metadata.isDeviceActive,
          );
        }),
      );

  /// Atomically replaces all local ledger rows (`transaction_audit_logs`,
  /// `transactions`, `customers`), clears any superseded in-flight backup
  /// batch (`backup_in_flight_batches`), and updates `backup_metadata` inside
  /// one SQLite transaction.
  ///
  /// Preserves `backup_device_identities` untouched. If [verifyInstallAllowed],
  /// [verifyBeforeCommit], or [tryEnterCommit] returns `false`, or if any
  /// constraint/interceptor error occurs before commit, rolls back all changes
  /// and leaves every table and backup marker intact.
  Future<
    ({RestoreLedgerCountsSnapshot counts, BackupMetadataSnapshot metadata})?
  >
  installConfirmedSnapshot({
    required List<CustomersCompanion> restoredCustomers,
    required List<TransactionsCompanion> restoredTransactions,
    required List<TransactionAuditLogsCompanion> restoredAuditLogs,
    required Future<bool> Function(
      RestoreLedgerCountsSnapshot currentCounts,
      BackupMetadataSnapshot currentMetadata,
    )
    verifyInstallAllowed,
    required bool Function() verifyBeforeCommit,
    Future<bool> Function()? tryEnterCommit,
    Future<void> Function()? onExitCommitAsync,
    required BackupMetadataSnapshot Function(BackupMetadataSnapshot latest)
    updateMetadata,
    Future<void> Function()? afterDeleteBeforeInsertHook,
  }) => runDatabaseOperation(() async {
    var commitEntered = false;
    try {
      return await transaction(() async {
        final currentMetadata = await _readMetadata();
        final currentCounts = await _readRestoreLedgerCountsInternal(
          isDeviceActive: currentMetadata.isDeviceActive,
        );
        final allowed = await verifyInstallAllowed(
          currentCounts,
          currentMetadata,
        );
        if (!allowed) return null;

        // Delete existing rows in child-to-parent foreign-key order and
        // invalidate any superseded pending in-flight batch.
        await delete(transactionAuditLogs).go();
        await delete(transactions).go();
        await delete(customers).go();
        await delete(backupInFlightBatches).go();

        if (afterDeleteBeforeInsertHook != null) {
          await afterDeleteBeforeInsertHook();
        }

        // Insert restored rows in parent-to-child foreign-key order without
        // generating any new audit log entries.
        for (final customer in restoredCustomers) {
          await into(customers).insert(customer);
        }
        for (final tx in restoredTransactions) {
          await into(transactions).insert(tx);
        }
        for (final audit in restoredAuditLogs) {
          await into(transactionAuditLogs).insert(audit);
        }

        final nextMetadata = updateMetadata(currentMetadata);
        await _writeMetadata(nextMetadata);

        final postCounts = await _readRestoreLedgerCountsInternal(
          isDeviceActive: nextMetadata.isDeviceActive,
        );

        if (!verifyBeforeCommit()) {
          throw const _AcknowledgmentRollbackSignal();
        }
        if (tryEnterCommit != null) {
          final entered = await tryEnterCommit();
          if (!entered) {
            throw const _AcknowledgmentRollbackSignal();
          }
          commitEntered = true;
        }

        return (counts: postCounts, metadata: nextMetadata);
      });
    } on _AcknowledgmentRollbackSignal {
      return null;
    } finally {
      if (commitEntered && onExitCommitAsync != null) {
        await onExitCommitAsync();
      }
    }
  });

  Future<RestoreLedgerCountsSnapshot> _readRestoreLedgerCountsInternal({
    required bool isDeviceActive,
  }) async {
    final allCustomers = await (select(
      customers,
    )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
    final allTransactions = await (select(
      transactions,
    )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
    final allAudits = await (select(
      transactionAuditLogs,
    )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();

    var activeCustomers = 0;
    var deletedCustomers = 0;
    var pendingCount = 0;
    var hash = 17;

    for (final c in allCustomers) {
      if (c.deletedAt == null) {
        activeCustomers++;
      } else {
        deletedCustomers++;
      }
      if (c.localRevision > c.acknowledgedRevision) {
        pendingCount++;
      }
      hash = _combineHash(hash, c.id.hashCode);
      hash = _combineHash(hash, c.name.hashCode);
      hash = _combineHash(hash, c.phone?.hashCode ?? 0);
      hash = _combineHash(hash, c.notes?.hashCode ?? 0);
      hash = _combineHash(hash, c.localRevision);
      hash = _combineHash(hash, c.acknowledgedRevision);
      hash = _combineHash(hash, c.updatedAt.millisecondsSinceEpoch);
      hash = _combineHash(hash, c.deletedAt?.millisecondsSinceEpoch ?? 0);
    }

    var activeTransactions = 0;
    var deletedTransactions = 0;
    for (final t in allTransactions) {
      if (t.deletedAt == null) {
        activeTransactions++;
      } else {
        deletedTransactions++;
      }
      if (t.localRevision > t.acknowledgedRevision) {
        pendingCount++;
      }
      hash = _combineHash(hash, t.id.hashCode);
      hash = _combineHash(hash, t.customerId.hashCode);
      hash = _combineHash(hash, t.type.hashCode);
      hash = _combineHash(hash, t.amountPiasters);
      hash = _combineHash(hash, t.note?.hashCode ?? 0);
      hash = _combineHash(hash, t.localRevision);
      hash = _combineHash(hash, t.acknowledgedRevision);
      hash = _combineHash(hash, t.updatedAt.millisecondsSinceEpoch);
      hash = _combineHash(hash, t.deletedAt?.millisecondsSinceEpoch ?? 0);
    }

    for (final a in allAudits) {
      if (a.localRevision > a.acknowledgedRevision) {
        pendingCount++;
      }
      hash = _combineHash(hash, a.id.hashCode);
      hash = _combineHash(hash, a.transactionId.hashCode);
      hash = _combineHash(hash, a.action.hashCode);
      hash = _combineHash(hash, a.previousAmountPiasters);
      hash = _combineHash(hash, a.localRevision);
      hash = _combineHash(hash, a.acknowledgedRevision);
      hash = _combineHash(hash, a.createdAt.millisecondsSinceEpoch);
    }

    final revisionStamp =
        'c:$activeCustomers:$deletedCustomers|'
        't:$activeTransactions:$deletedTransactions|'
        'a:${allAudits.length}|p:$pendingCount|h:$hash';

    return RestoreLedgerCountsSnapshot(
      customerCount: activeCustomers,
      deletedCustomerCount: deletedCustomers,
      transactionCount: activeTransactions,
      deletedTransactionCount: deletedTransactions,
      auditLogCount: allAudits.length,
      pendingChangesCount: pendingCount,
      isDeviceActive: isDeviceActive,
      revisionStamp: revisionStamp,
    );
  }

  static int _combineHash(int current, int value) =>
      ((current * 31) ^ value) & 0x7fffffff;

  /// Returns `true` when [currentCounts] already reflects the exact installed
  /// rows of [restoredCustomers], [restoredTransactions], and
  /// [restoredAuditLogs] with zero pending changes.
  ///
  /// Used to make recovery idempotent if an earlier local installation
  /// transaction committed in SQLite right before the app was interrupted.
  static bool matchesInstalledCompanions({
    required RestoreLedgerCountsSnapshot currentCounts,
    required List<CustomersCompanion> restoredCustomers,
    required List<TransactionsCompanion> restoredTransactions,
    required List<TransactionAuditLogsCompanion> restoredAuditLogs,
  }) {
    if (currentCounts.pendingChangesCount != 0) return false;
    final stampSeconds = _computeCompanionRevisionStamp(
      restoredCustomers: restoredCustomers,
      restoredTransactions: restoredTransactions,
      restoredAuditLogs: restoredAuditLogs,
      truncateToSeconds: true,
    );
    if (currentCounts.revisionStamp == stampSeconds) return true;
    final stampMillis = _computeCompanionRevisionStamp(
      restoredCustomers: restoredCustomers,
      restoredTransactions: restoredTransactions,
      restoredAuditLogs: restoredAuditLogs,
      truncateToSeconds: false,
    );
    return currentCounts.revisionStamp == stampMillis;
  }

  static String _computeCompanionRevisionStamp({
    required List<CustomersCompanion> restoredCustomers,
    required List<TransactionsCompanion> restoredTransactions,
    required List<TransactionAuditLogsCompanion> restoredAuditLogs,
    required bool truncateToSeconds,
  }) {
    final sortedCustomers = List<CustomersCompanion>.of(restoredCustomers)
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    final sortedTransactions = List<TransactionsCompanion>.of(
      restoredTransactions,
    )..sort((a, b) => a.id.value.compareTo(b.id.value));
    final sortedAudits = List<TransactionAuditLogsCompanion>.of(
      restoredAuditLogs,
    )..sort((a, b) => a.id.value.compareTo(b.id.value));

    var activeCustomers = 0;
    var deletedCustomers = 0;
    var pendingCount = 0;
    var hash = 17;

    for (final c in sortedCustomers) {
      final deletedAt = c.deletedAt.value;
      if (deletedAt == null) {
        activeCustomers++;
      } else {
        deletedCustomers++;
      }
      if (c.localRevision.value > c.acknowledgedRevision.value) {
        pendingCount++;
      }
      hash = _combineHash(hash, c.id.value.hashCode);
      hash = _combineHash(hash, c.name.value.hashCode);
      hash = _combineHash(hash, c.phone.value?.hashCode ?? 0);
      hash = _combineHash(hash, c.notes.value?.hashCode ?? 0);
      hash = _combineHash(hash, c.localRevision.value);
      hash = _combineHash(hash, c.acknowledgedRevision.value);
      hash = _combineHash(hash, _epochMs(c.updatedAt.value, truncateToSeconds));
      hash = _combineHash(
        hash,
        deletedAt == null ? 0 : _epochMs(deletedAt, truncateToSeconds),
      );
    }

    var activeTransactions = 0;
    var deletedTransactions = 0;
    for (final t in sortedTransactions) {
      final deletedAt = t.deletedAt.value;
      if (deletedAt == null) {
        activeTransactions++;
      } else {
        deletedTransactions++;
      }
      if (t.localRevision.value > t.acknowledgedRevision.value) {
        pendingCount++;
      }
      hash = _combineHash(hash, t.id.value.hashCode);
      hash = _combineHash(hash, t.customerId.value.hashCode);
      hash = _combineHash(hash, t.type.value.hashCode);
      hash = _combineHash(hash, t.amountPiasters.value);
      hash = _combineHash(hash, t.note.value?.hashCode ?? 0);
      hash = _combineHash(hash, t.localRevision.value);
      hash = _combineHash(hash, t.acknowledgedRevision.value);
      hash = _combineHash(hash, _epochMs(t.updatedAt.value, truncateToSeconds));
      hash = _combineHash(
        hash,
        deletedAt == null ? 0 : _epochMs(deletedAt, truncateToSeconds),
      );
    }

    for (final a in sortedAudits) {
      if (a.localRevision.value > a.acknowledgedRevision.value) {
        pendingCount++;
      }
      hash = _combineHash(hash, a.id.value.hashCode);
      hash = _combineHash(hash, a.transactionId.value.hashCode);
      hash = _combineHash(hash, a.action.value.hashCode);
      hash = _combineHash(hash, a.previousAmountPiasters.value);
      hash = _combineHash(hash, a.localRevision.value);
      hash = _combineHash(hash, a.acknowledgedRevision.value);
      hash = _combineHash(hash, _epochMs(a.createdAt.value, truncateToSeconds));
    }

    return 'c:$activeCustomers:$deletedCustomers|'
        't:$activeTransactions:$deletedTransactions|'
        'a:${sortedAudits.length}|p:$pendingCount|h:$hash';
  }

  static int _epochMs(DateTime dt, bool truncateToSeconds) {
    final ms = dt.millisecondsSinceEpoch;
    return truncateToSeconds ? (ms ~/ 1000) * 1000 : ms;
  }

  Future<BackupMetadataSnapshot> _readMetadata() async {
    final row = await (select(
      backupMetadata,
    )..where((r) => r.id.equals(_singletonRowId))).getSingleOrNull();
    if (row == null) return const BackupMetadataSnapshot.initial();
    return BackupMetadataSnapshot(
      schedule: row.schedule,
      lastConfirmedAtIso: row.lastConfirmedAtIso,
      nextDueAtIso: row.nextDueAtIso,
      isDeviceActive: row.isDeviceActive,
    );
  }

  Future<void> _writeMetadata(BackupMetadataSnapshot snapshot) {
    return into(backupMetadata).insertOnConflictUpdate(
      BackupMetadataCompanion(
        id: const Value(_singletonRowId),
        schedule: Value(snapshot.schedule),
        lastConfirmedAtIso: Value(snapshot.lastConfirmedAtIso),
        nextDueAtIso: Value(snapshot.nextDueAtIso),
        isDeviceActive: Value(snapshot.isDeviceActive),
      ),
    );
  }

  Future<int> _countPendingChanges() async {
    final customerCount = customers.id.count();
    final customerQuery = selectOnly(customers)
      ..addColumns([customerCount])
      ..where(
        customers.localRevision.isBiggerThan(customers.acknowledgedRevision),
      );

    final transactionCount = transactions.id.count();
    final transactionQuery = selectOnly(transactions)
      ..addColumns([transactionCount])
      ..where(
        transactions.localRevision.isBiggerThan(
          transactions.acknowledgedRevision,
        ),
      );

    final auditCount = transactionAuditLogs.id.count();
    final auditQuery = selectOnly(transactionAuditLogs)
      ..addColumns([auditCount])
      ..where(
        transactionAuditLogs.localRevision.isBiggerThan(
          transactionAuditLogs.acknowledgedRevision,
        ),
      );

    final pendingCustomers =
        (await customerQuery.getSingle()).read(customerCount) ?? 0;
    final pendingTransactions =
        (await transactionQuery.getSingle()).read(transactionCount) ?? 0;
    final pendingAuditLogs =
        (await auditQuery.getSingle()).read(auditCount) ?? 0;

    return pendingCustomers + pendingTransactions + pendingAuditLogs;
  }
}
