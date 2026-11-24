import 'package:drift/drift.dart';

/// Persisted backup schedule, server-confirmed timestamp, and device authority.
///
/// Constrained to a single row (`id = 1`) so schedule updates, device
/// deactivation, and batch acknowledgments serialize inside SQLite transactions.
@DataClassName('BackupMetadataRow')
class BackupMetadata extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  TextColumn get schedule => text().nullable()();

  TextColumn get lastConfirmedAtIso => text().nullable()();

  TextColumn get nextDueAtIso => text().nullable()();

  BoolColumn get isDeviceActive =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (id = 1)',
    "CHECK (schedule IS NULL OR schedule IN ('daily', 'weekly', 'monthly'))",
    'CHECK ((schedule IS NULL AND next_due_at_iso IS NULL) OR (schedule IS NOT NULL AND next_due_at_iso IS NOT NULL))',
  ];
}
