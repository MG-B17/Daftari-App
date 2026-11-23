import 'package:drift/drift.dart';

/// Single durable unacknowledged backup batch captured prior to cloud
/// publication.
///
/// Constrained to a single row (`id = 1`) so an interrupted publication or
/// lost acknowledgment always recovers the exact captured batch snapshot and
/// revisions across process restarts.
@DataClassName('BackupInFlightBatchRow')
class BackupInFlightBatches extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  TextColumn get batchId => text()();

  TextColumn get ownerUserId => text()();

  TextColumn get deviceId => text()();

  TextColumn get capturedAtIso => text()();

  TextColumn get payloadJson => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (id = 1)',
    'CHECK (length(trim(batch_id)) > 0)',
    'CHECK (length(trim(owner_user_id)) > 0)',
    'CHECK (length(trim(device_id)) > 0)',
    'CHECK (length(trim(captured_at_iso)) > 0)',
    'CHECK (length(trim(payload_json)) > 0)',
  ];
}
