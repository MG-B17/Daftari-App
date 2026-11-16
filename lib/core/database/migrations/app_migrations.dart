import 'package:drift/drift.dart';

/// Single source of truth for the schema version and migration strategy.
abstract final class AppMigrations {
  static const schemaVersion = 1;

  static MigrationStrategy strategy(GeneratedDatabase database) {
    return MigrationStrategy(
      onCreate: (migrator) => migrator.createAll(),
      onUpgrade: upgrade,
      beforeOpen: (details) async {
        // SQLite enables foreign keys per connection, and they are off by
        // default. Tests and production both go through this hook.
        await database.customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Centralizes incremental upgrades. Schema version 1 is the initial schema
  /// created by [strategy]'s `onCreate`, so no upgrade step is needed yet.
  ///
  /// Future versions append their step here in ascending order, for example:
  /// ```dart
  /// if (from < 2 && to >= 2) {
  ///   await migrator.addColumn(transactions, transactions.example);
  /// }
  /// ```
  static Future<void> upgrade(Migrator migrator, int from, int to) async {
    assert(from < to, 'Upgrade target must be newer than the stored schema.');
  }
}
