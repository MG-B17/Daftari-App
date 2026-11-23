import 'dart:async';
import 'dart:io';

import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/features/backup/data/services/backup_device_storage.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _InterleavingExecutorInterceptor extends QueryInterceptor {
  _InterleavingExecutorInterceptor({required this.onFirstReadDeviceId});

  final Future<void> Function() onFirstReadDeviceId;
  bool _intercepted = false;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final rows = await executor.runSelect(statement, args);
    if (!_intercepted &&
        statement.contains('backup_device_identities') &&
        rows.isEmpty) {
      _intercepted = true;
      await onFirstReadDeviceId();
    }
    return rows;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late File databaseFile;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp(
      'daftari_device_storage_test_',
    );
    databaseFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}device_identity.sqlite',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('generates a durable identity once and returns the same pair across restarts', () async {
    const secureStorage = FlutterSecureStorage();
    final db1 = AppDatabase(NativeDatabase(databaseFile));
    late BackupDeviceIdentity created;
    try {
      final storage1 = BackupDeviceStorage(secureStorage, db1.backupDao);
      created = await storage1.getOrCreateIdentity();
      expect(created.deviceId, isNotEmpty);
      expect(
        created.deviceSecret.length,
        greaterThanOrEqualTo(BackupDeviceStorage.minSecretLength),
      );
      expect(await storage1.readIdentity(), created);
    } finally {
      await db1.close();
    }

    final db2 = AppDatabase(NativeDatabase(databaseFile));
    try {
      final storage2 = BackupDeviceStorage(
        secureStorage,
        db2.backupDao,
        generateDeviceId: () => 'unexpected-second-id',
        generateDeviceSecret: () => 'f'.padRight(64, 'f'),
      );
      expect(await storage2.getOrCreateIdentity(), created);
      expect(await storage2.readDeviceId(), created.deviceId);
    } finally {
      await db2.close();
    }
  });

  test('P12-12: two independent storage instances across separate connections interleaving first reads on the same empty store converge on one durable identity', () async {
    final previousWarnSetting =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases =
          previousWarnSetting,
    );

    // Initialize the empty database schema on disk first (still zero device identity rows).
    final initDb = AppDatabase(NativeDatabase(databaseFile));
    try {
      expect(await initDb.backupDao.readDeviceId(), isNull);
    } finally {
      await initDb.close();
    }

    const secureStorage = FlutterSecureStorage();
    final secret1 = '1'.padRight(64, 'a');
    final secret2 = '2'.padRight(64, 'b');

    final instance1ReadEmpty = Completer<void>();
    final instance2ReadEmpty = Completer<void>();
    final releaseBoth = Completer<void>();

    // Two completely independent database connections (background isolates,
    // mirroring foreground app + background worker) sharing the same file and
    // secure storage.
    final db1 = AppDatabase(
      NativeDatabase.createInBackground(databaseFile).interceptWith(
        _InterleavingExecutorInterceptor(
          onFirstReadDeviceId: () async {
            instance1ReadEmpty.complete();
            await releaseBoth.future;
          },
        ),
      ),
    );
    final db2 = AppDatabase(
      NativeDatabase.createInBackground(databaseFile).interceptWith(
        _InterleavingExecutorInterceptor(
          onFirstReadDeviceId: () async {
            instance2ReadEmpty.complete();
            await releaseBoth.future;
          },
        ),
      ),
    );

    late BackupDeviceIdentity id1;
    late BackupDeviceIdentity id2;
    try {
      final storage1 = BackupDeviceStorage(
        secureStorage,
        db1.backupDao,
        generateDeviceId: () => '11111111-1111-4111-8111-111111111111',
        generateDeviceSecret: () => secret1,
      );
      final storage2 = BackupDeviceStorage(
        secureStorage,
        db2.backupDao,
        generateDeviceId: () => '22222222-2222-4222-8222-222222222222',
        generateDeviceSecret: () => secret2,
      );

      final future1 = storage1.getOrCreateIdentity();
      final future2 = storage2.getOrCreateIdentity();

      // Wait until BOTH independent instances have observed an empty store.
      await Future.wait([instance1ReadEmpty.future, instance2ReadEmpty.future]);
      releaseBoth.complete();

      final results = await Future.wait([future1, future2]);
      id1 = results[0];
      id2 = results[1];

      expect(id1, equals(id2));
      final loserId = id1.deviceId == '11111111-1111-4111-8111-111111111111'
          ? '22222222-2222-4222-8222-222222222222'
          : '11111111-1111-4111-8111-111111111111';
      expect(
        await secureStorage.read(
          key: BackupDeviceStorage.secretKeyFor(loserId),
        ),
        isNull,
      );
      expect(
        await secureStorage.read(
          key: BackupDeviceStorage.secretKeyFor(id1.deviceId),
        ),
        id1.deviceSecret,
      );
    } finally {
      await db1.close();
      await db2.close();
    }

    // Restarted third instance sees the exact same converged identity.
    final db3 = AppDatabase(NativeDatabase(databaseFile));
    try {
      final storage3 = BackupDeviceStorage(
        secureStorage,
        db3.backupDao,
        generateDeviceId: () => '33333333-3333-4333-8333-333333333333',
        generateDeviceSecret: () => '3'.padRight(64, 'c'),
      );
      expect(await storage3.getOrCreateIdentity(), id1);
    } finally {
      await db3.close();
    }
  });

  test('translates secure storage errors into StorageException and validates generated values', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final failingStorage = _MockSecureStorage();
    when(
      () => failingStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenThrow(Exception('keystore locked'));

    final deviceStorage = BackupDeviceStorage(failingStorage, db.backupDao);
    await expectLater(
      deviceStorage.getOrCreateIdentity(),
      throwsA(isA<StorageException>()),
    );
    expect(await db.backupDao.readDeviceId(), isNull);

    const okStorage = FlutterSecureStorage();
    final badIdStorage = BackupDeviceStorage(
      okStorage,
      db.backupDao,
      generateDeviceId: () => '   ',
    );
    await expectLater(
      badIdStorage.getOrCreateIdentity(),
      throwsA(isA<ValidationException>()),
    );

    final shortSecretStorage = BackupDeviceStorage(
      okStorage,
      db.backupDao,
      generateDeviceSecret: () => 'too-short',
    );
    await expectLater(
      shortSecretStorage.getOrCreateIdentity(),
      throwsA(isA<ValidationException>()),
    );
  });

  test('P12-13: BackupDeviceIdentity redacts raw deviceSecret even when EquatableConfig.stringify is enabled', () {
    final previousStringify = EquatableConfig.stringify;
    EquatableConfig.stringify = true;
    addTearDown(() => EquatableConfig.stringify = previousStringify);

    const syntheticSecret =
        'synthetic-device-secret-9f8e7d6c5b4a32109f8e7d6c5b4a3210';
    const identity = BackupDeviceIdentity(
      deviceId: '11111111-1111-4111-8111-111111111111',
      deviceSecret: syntheticSecret,
    );

    final formatted = identity.toString();
    expect(formatted, isNot(contains(syntheticSecret)));
    expect(formatted, contains('<redacted>'));
    expect(formatted, contains(identity.deviceId));
  });
}
