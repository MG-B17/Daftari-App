import 'package:drift/drift.dart';

import '../app_database.dart';

/// Single source of truth for the schema version and migration strategy.
abstract final class AppMigrations {
  static const schemaVersion = 2;

  static MigrationStrategy strategy(AppDatabase database) {
    return MigrationStrategy(
      onCreate: (migrator) => migrator.createAll(),
      onUpgrade: (migrator, from, to) => upgrade(database, migrator, from, to),
      beforeOpen: (details) async {
        // SQLite enables foreign keys per connection, and they are off by
        // default. Tests and production both go through this hook.
        await database.customStatement('PRAGMA foreign_keys = ON');
        await database.customStatement('PRAGMA busy_timeout = 5000');
        await database.customStatement(
          'CREATE TABLE IF NOT EXISTS backup_ledger_owner ('
          'id INTEGER NOT NULL PRIMARY KEY CHECK (id = 1), '
          'owner_user_id TEXT NOT NULL'
          ')',
        );
      },
    );
  }

  /// Centralizes incremental schema upgrades in ascending version order.
  static Future<void> upgrade(
    AppDatabase database,
    Migrator migrator,
    int from,
    int to,
  ) async {
    assert(from < to, 'Upgrade target must be newer than the stored schema.');
    if (from < 2 && to >= 2) {
      await migrator.addColumn(
        database.customers,
        database.customers.acknowledgedRevision,
      );
      await migrator.addColumn(
        database.transactions,
        database.transactions.acknowledgedRevision,
      );
      await migrator.addColumn(
        database.transactionAuditLogs,
        database.transactionAuditLogs.acknowledgedRevision,
      );
      await migrator.createTable(database.backupMetadata);
      await migrator.createTable(database.backupInFlightBatches);
      await migrator.createTable(database.backupDeviceIdentities);
    }
  }
}
