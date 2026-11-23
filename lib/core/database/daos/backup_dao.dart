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
        onEnterCommit?.call();
        commitEntered = true;

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
