import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/customer_dao.dart';
import 'daos/transaction_dao.dart';
import 'migrations/app_migrations.dart';
import 'tables/customers_table.dart';
import 'tables/transaction_audit_logs_table.dart';
import 'tables/transactions_table.dart';

export 'daos/customer_dao.dart';
export 'daos/transaction_dao.dart';
export 'tables/customers_table.dart';
export 'tables/transaction_audit_logs_table.dart';
export 'tables/transactions_table.dart';

part 'app_database.g.dart';

/// Offline-first SQLite database backing the local ledger.
///
/// The default constructor opens the `daftari` database file. Tests can inject
/// any [QueryExecutor], including [NativeDatabase.memory].
@DriftDatabase(
  tables: [Customers, Transactions, TransactionAuditLogs],
  daos: [CustomerDao, TransactionDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'daftari'));

  @override
  int get schemaVersion => AppMigrations.schemaVersion;

  @override
  MigrationStrategy get migration => AppMigrations.strategy(this);
}
