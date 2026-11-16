// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_dao.dart';

// ignore_for_file: type=lint
mixin _$TransactionDaoMixin on DatabaseAccessor<AppDatabase> {
  $CustomersTable get customers => attachedDatabase.customers;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $TransactionAuditLogsTable get transactionAuditLogs =>
      attachedDatabase.transactionAuditLogs;
  TransactionDaoManager get managers => TransactionDaoManager(this);
}

class TransactionDaoManager {
  final _$TransactionDaoMixin _db;
  TransactionDaoManager(this._db);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$TransactionAuditLogsTableTableManager get transactionAuditLogs =>
      $$TransactionAuditLogsTableTableManager(
        _db.attachedDatabase,
        _db.transactionAuditLogs,
      );
}
