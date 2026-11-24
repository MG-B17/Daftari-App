// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_dao.dart';

// ignore_for_file: type=lint
mixin _$BackupDaoMixin on DatabaseAccessor<AppDatabase> {
  $CustomersTable get customers => attachedDatabase.customers;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $TransactionAuditLogsTable get transactionAuditLogs =>
      attachedDatabase.transactionAuditLogs;
  $BackupMetadataTable get backupMetadata => attachedDatabase.backupMetadata;
  $BackupInFlightBatchesTable get backupInFlightBatches =>
      attachedDatabase.backupInFlightBatches;
  $BackupDeviceIdentitiesTable get backupDeviceIdentities =>
      attachedDatabase.backupDeviceIdentities;
  BackupDaoManager get managers => BackupDaoManager(this);
}

class BackupDaoManager {
  final _$BackupDaoMixin _db;
  BackupDaoManager(this._db);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$TransactionAuditLogsTableTableManager get transactionAuditLogs =>
      $$TransactionAuditLogsTableTableManager(
        _db.attachedDatabase,
        _db.transactionAuditLogs,
      );
  $$BackupMetadataTableTableManager get backupMetadata =>
      $$BackupMetadataTableTableManager(
        _db.attachedDatabase,
        _db.backupMetadata,
      );
  $$BackupInFlightBatchesTableTableManager get backupInFlightBatches =>
      $$BackupInFlightBatchesTableTableManager(
        _db.attachedDatabase,
        _db.backupInFlightBatches,
      );
  $$BackupDeviceIdentitiesTableTableManager get backupDeviceIdentities =>
      $$BackupDeviceIdentitiesTableTableManager(
        _db.attachedDatabase,
        _db.backupDeviceIdentities,
      );
}
