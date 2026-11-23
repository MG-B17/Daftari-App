import 'package:drift/drift.dart';

/// Single durable installation identifier for cloud backup.
///
/// Constrained to a single row (`id = 1`) and claimed via `INSERT OR IGNORE`
/// so concurrent foreground and worker instances converge on one canonical
/// device ID.
@DataClassName('BackupDeviceIdentityRow')
class BackupDeviceIdentities extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  TextColumn get deviceId => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (id = 1)',
    'CHECK (length(trim(device_id)) > 0)',
  ];
}
