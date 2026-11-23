import 'dart:io';

import 'package:daftariapp/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal Drift database helper that initializes a real SQLite file with the
/// exact Phase 4 (schemaVersion 1) DDL and pre-existing ledger rows.
class _V1FixtureDatabase extends GeneratedDatabase {
  _V1FixtureDatabase(super.executor);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('''
        CREATE TABLE customers (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT NULL,
          notes TEXT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER NULL,
          local_revision INTEGER NOT NULL DEFAULT 1,
          synced_at INTEGER NULL
        )
      ''');
      await customStatement(
        'CREATE INDEX idx_customers_deleted_at ON customers (deleted_at)',
      );
      await customStatement(
        'CREATE INDEX idx_customers_name ON customers (name)',
      );
      await customStatement('''
        CREATE TABLE transactions (
          id TEXT NOT NULL PRIMARY KEY,
          customer_id TEXT NOT NULL REFERENCES customers (id) ON DELETE RESTRICT,
          type TEXT NOT NULL,
          amount_piasters INTEGER NOT NULL,
          note TEXT NULL,
          transaction_date INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER NULL,
          local_revision INTEGER NOT NULL DEFAULT 1,
          synced_at INTEGER NULL,
          CHECK (type IN ('credit', 'payment')),
          CHECK (amount_piasters > 0)
        )
      ''');
      await customStatement(
        'CREATE INDEX idx_transactions_customer_id ON transactions (customer_id)',
      );
      await customStatement(
        'CREATE INDEX idx_transactions_deleted_at ON transactions (deleted_at)',
      );
      await customStatement(
        'CREATE INDEX idx_transactions_transaction_date ON transactions (transaction_date)',
      );
      await customStatement(
        'CREATE INDEX idx_transactions_customer_deleted ON transactions (customer_id, deleted_at)',
      );
      await customStatement('''
        CREATE TABLE transaction_audit_logs (
          id TEXT NOT NULL PRIMARY KEY,
          transaction_id TEXT NOT NULL REFERENCES transactions (id) ON DELETE RESTRICT,
          action TEXT NOT NULL,
          previous_type TEXT NOT NULL,
          previous_amount_piasters INTEGER NOT NULL,
          previous_note TEXT NULL,
          previous_transaction_date INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          local_revision INTEGER NOT NULL DEFAULT 1,
          synced_at INTEGER NULL
        )
      ''');
      await customStatement(
        'CREATE INDEX idx_transaction_audit_logs_transaction_id ON transaction_audit_logs (transaction_id)',
      );
    },
  );
}

void main() {
  late Directory tempDirectory;
  late File databaseFile;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'daftari_backup_migration_test_',
    );
    databaseFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}daftari_v1.sqlite',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('upgrades schema v1 ledger to v2, preserves all rows and marks existing data pending for first backup', () async {
    final epoch = DateTime.utc(2026, 10, 1, 9).millisecondsSinceEpoch ~/ 1000;

    final v1 = _V1FixtureDatabase(NativeDatabase(databaseFile));
    try {
      await v1.customStatement(
        '''
        INSERT INTO customers (id, name, phone, notes, created_at, updated_at, deleted_at, local_revision, synced_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'cust-active',
          'Ahmed',
          '01001112222',
          null,
          epoch,
          epoch,
          null,
          1,
          null,
        ],
      );
      await v1.customStatement(
        '''
        INSERT INTO customers (id, name, phone, notes, created_at, updated_at, deleted_at, local_revision, synced_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'cust-deleted',
          'Archived',
          null,
          'old',
          epoch,
          epoch + 10,
          epoch + 10,
          2,
          null,
        ],
      );
      await v1.customStatement(
        '''
        INSERT INTO transactions (id, customer_id, type, amount_piasters, note, transaction_date, created_at, updated_at, deleted_at, local_revision, synced_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'tx-edited',
          'cust-active',
          'credit',
          15000,
          'updated',
          epoch,
          epoch,
          epoch + 5,
          null,
          2,
          null,
        ],
      );
      await v1.customStatement(
        '''
        INSERT INTO transactions (id, customer_id, type, amount_piasters, note, transaction_date, created_at, updated_at, deleted_at, local_revision, synced_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'tx-deleted',
          'cust-active',
          'payment',
          5000,
          null,
          epoch,
          epoch,
          epoch + 6,
          epoch + 6,
          2,
          null,
        ],
      );
      await v1.customStatement(
        '''
        INSERT INTO transaction_audit_logs (id, transaction_id, action, previous_type, previous_amount_piasters, previous_note, previous_transaction_date, created_at, local_revision, synced_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'audit-edit',
          'tx-edited',
          'edit',
          'credit',
          10000,
          'initial',
          epoch,
          epoch + 5,
          1,
          null,
        ],
      );
      await v1.customStatement(
        '''
        INSERT INTO transaction_audit_logs (id, transaction_id, action, previous_type, previous_amount_piasters, previous_note, previous_transaction_date, created_at, local_revision, synced_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'audit-delete',
          'tx-deleted',
          'delete',
          'payment',
          5000,
          null,
          epoch,
          epoch + 6,
          1,
          null,
        ],
      );

      final v1Version = await v1
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(v1Version.data['user_version'], 1);
    } finally {
      await v1.close();
    }

    final upgraded = AppDatabase(NativeDatabase(databaseFile));
    try {
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data['user_version'], 2);

      final fkPragma = await upgraded
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(fkPragma.data['foreign_keys'], 1);

      final activeCustomer = await upgraded.customerDao.getCustomerById(
        'cust-active',
      );
      expect(activeCustomer, isNotNull);
      expect(activeCustomer!.localRevision, 1);
      expect(activeCustomer.acknowledgedRevision, 0);

      final deletedCustomer = await upgraded.customerDao.getCustomerById(
        'cust-deleted',
        includeDeleted: true,
      );
      expect(deletedCustomer, isNotNull);
      expect(deletedCustomer!.deletedAt, isNotNull);
      expect(deletedCustomer.localRevision, 2);
      expect(deletedCustomer.acknowledgedRevision, 0);

      final editedTx = await upgraded.transactionDao.getTransactionById(
        'tx-edited',
      );
      expect(editedTx, isNotNull);
      expect(editedTx!.amountPiasters, 15000);
      expect(editedTx.localRevision, 2);
      expect(editedTx.acknowledgedRevision, 0);

      final deletedTx = await upgraded.transactionDao.getTransactionById(
        'tx-deleted',
        includeDeleted: true,
      );
      expect(deletedTx, isNotNull);
      expect(deletedTx!.deletedAt, isNotNull);
      expect(deletedTx.localRevision, 2);
      expect(deletedTx.acknowledgedRevision, 0);

      final editAudits = await upgraded.transactionDao.getAuditLogs(
        'tx-edited',
      );
      expect(editAudits, hasLength(1));
      expect(editAudits.single.id, 'audit-edit');
      expect(editAudits.single.acknowledgedRevision, 0);

      final deleteAudits = await upgraded.transactionDao.getAuditLogs(
        'tx-deleted',
      );
      expect(deleteAudits, hasLength(1));
      expect(deleteAudits.single.id, 'audit-delete');
      expect(deleteAudits.single.acknowledgedRevision, 0);

      // All 6 pre-existing records (2 customers, 2 transactions, 2 audits) are pending.
      final localStatus = await upgraded.backupDao.readLocalStatus();
      expect(localStatus.isDeviceActive, isTrue);
      expect(localStatus.pendingChangesCount, 6);
      expect(await upgraded.backupDao.readInFlightBatch(), isNull);
      expect(await upgraded.backupDao.readDeviceId(), isNull);
      expect(
        await upgraded.backupDao.claimOrReadDeviceId('device-after-upgrade'),
        'device-after-upgrade',
      );
      expect(
        await upgraded.backupDao.readMetadata(),
        const BackupMetadataSnapshot.initial(),
      );
    } finally {
      await upgraded.close();
    }
  });
}
