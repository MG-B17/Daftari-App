import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/core/services/connectivity/connectivity_service.dart';
import 'package:daftariapp/core/services/loacl_storage/local_storage_service.dart';
import 'package:daftariapp/core/services/session_commit_gate/session_commit_gate.dart';
import 'package:daftariapp/features/auth/session/data/services/ledger_owner_storage.dart';
import 'package:daftariapp/features/auth/session/data/services/supabase_auth_service.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
import 'package:daftariapp/features/backup/data/repositories/drift_backup_local_store.dart';
import 'package:daftariapp/features/backup/data/services/backup_device_storage.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_batch.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_eligibility.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_run_result.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_schedule.dart';
import 'package:daftariapp/features/backup/domain/usecases/run_backup_usecase.dart';
import 'package:daftariapp/features/restore/data/repositories/drift_restore_local_store.dart';
import 'package:daftariapp/features/restore/domain/entities/restore_entities.dart';
import 'package:daftariapp/features/restore/domain/policies/restore_snapshot_validator.dart';
import 'package:daftariapp/features/restore/domain/repositories/restore_local_store.dart';
import 'package:daftariapp/features/security/data/services/secure_storage_service.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backup/domain/backup_domain_fakes.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.user, this.commitGate});

  final StreamController<AuthSessionEvent> _authController =
      StreamController<AuthSessionEvent>.broadcast();
  final SessionCommitGate? commitGate;

  AuthUser? user;

  @override
  bool get isConfigured => true;

  @override
  AuthUser? get currentUser => user;

  @override
  Future<AuthUser?> getCurrentUser() async => user;

  @override
  Stream<AuthSessionEvent> watchAuthChanges() => _authController.stream;

  @override
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthUser> signUpWithPassword({
    required String email,
    required String password,
    required String shopName,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut({String? expectedUserId}) {
    Future<void> performSignOut() async {
      user = null;
      _authController.add(const AuthSessionSignedOut());
    }

    final gate = commitGate;
    return gate == null
        ? performSignOut()
        : gate.runSessionInvalidation(performSignOut);
  }

  void signIn(AuthUser next) {
    user = next;
    _authController.add(AuthSessionSignedIn(next));
  }

  Future<void> dispose() => _authController.close();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> resendVerificationEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> updatePassword(String newPassword) => throw UnimplementedError();
}

class _MockConnectivity extends Mock implements Connectivity {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// Injects a SQLite failure mid-replacement AFTER existing tables have been
/// deleted and while replacement rows are being inserted.
class _FailDuringReplacementInsertInterceptor extends QueryInterceptor {
  String? failOnTable;
  int failedAttempts = 0;

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final target = failOnTable;
    if (target != null &&
        statement.toLowerCase().contains('insert into "$target"')) {
      failedAttempts++;
      throw Exception('Injected mid-replacement SQLite failure on $target');
    }
    return executor.runInsert(statement, args);
  }
}

final class _DatabaseFullDump {
  const _DatabaseFullDump({
    required this.customers,
    required this.transactions,
    required this.auditLogs,
    required this.inFlightBatch,
    required this.metadata,
    required this.deviceId,
    required this.pendingChangesCount,
  });

  final List<Customer> customers;
  final List<TransactionRecord> transactions;
  final List<TransactionAuditLog> auditLogs;
  final BackupInFlightBatchRow? inFlightBatch;
  final BackupMetadataSnapshot metadata;
  final String? deviceId;
  final int pendingChangesCount;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  const ownerUserId = '11111111-1111-4111-8111-111111111111';
  const otherUserId = '22222222-2222-4222-8222-222222222222';
  const receivingDeviceId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const oldActiveDeviceId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  final receivingDeviceSecret = 'b2' * 32;
  final confirmedAt = DateTime.utc(2026, 11, 25, 11, 30);

  late Directory tempDirectory;
  late File databaseFile;
  late SessionCommitGate commitGate;
  late _FakeAuthService authService;
  late _MockConnectivity connectivity;
  late ConnectivityService connectivityService;
  late ErrorHandler errorHandler;
  late FakeDateService clock;
  late FakeBackupCloudPublisher cloudPublisher;

  CloudBackupSnapshot sampleConfirmedSnapshot({
    String version = 'v-3',
    String ownerId = ownerUserId,
    String activeDeviceId = receivingDeviceId,
    DateTime? confirmedTime,
  }) {
    final t0 = DateTime.utc(2026, 11, 20, 8);
    final t1 = DateTime.utc(2026, 11, 22, 14, 15);
    final t2 = DateTime.utc(2026, 11, 24, 16, 45);
    final confirmed = confirmedTime ?? confirmedAt;

    final customers = [
      BackupCustomerRecord(
        id: 'cust-1',
        name: 'Mohamed Abdel Fattah',
        phone: '01001112222',
        notes: 'main shop',
        createdAt: t0,
        updatedAt: t1,
        deletedAt: null,
        localRevision: 2,
      ),
      BackupCustomerRecord(
        id: 'cust-2',
        name: 'Ahmed El Shenawy',
        phone: '01003334444',
        notes: null,
        createdAt: t0,
        updatedAt: t0,
        deletedAt: null,
        localRevision: 1,
      ),
      BackupCustomerRecord(
        id: 'cust-3-deleted',
        name: 'Former Customer',
        phone: '01005556666',
        notes: 'archived',
        createdAt: t0,
        updatedAt: t2,
        deletedAt: t2,
        localRevision: 3,
      ),
    ];

    final transactions = [
      // Active credit on cust-1: 30000 piasters (edited from 20000 -> rev 2)
      BackupTransactionRecord(
        id: 'tx-1',
        customerId: 'cust-1',
        type: TransactionType.credit,
        amountPiasters: 30000,
        note: 'sugar and oil',
        transactionDate: t0,
        createdAt: t0,
        updatedAt: t1,
        deletedAt: null,
        localRevision: 2,
      ),
      // Active payment on cust-1: 12500 piasters (rev 1)
      BackupTransactionRecord(
        id: 'tx-2',
        customerId: 'cust-1',
        type: TransactionType.payment,
        amountPiasters: 12500,
        note: 'cash installment',
        transactionDate: t1,
        createdAt: t1,
        updatedAt: t1,
        deletedAt: null,
        localRevision: 1,
      ),
      // Soft-deleted credit tombstone on cust-1: 8000 piasters (rev 2)
      BackupTransactionRecord(
        id: 'tx-3-deleted',
        customerId: 'cust-1',
        type: TransactionType.credit,
        amountPiasters: 8000,
        note: 'cancelled entry',
        transactionDate: t1,
        createdAt: t1,
        updatedAt: t2,
        deletedAt: t2,
        localRevision: 2,
      ),
      // Active credit on cust-2: 6000 piasters + active payment 6000 -> settled (0)
      BackupTransactionRecord(
        id: 'tx-4',
        customerId: 'cust-2',
        type: TransactionType.credit,
        amountPiasters: 6000,
        note: 'rice',
        transactionDate: t0,
        createdAt: t0,
        updatedAt: t0,
        deletedAt: null,
        localRevision: 1,
      ),
      BackupTransactionRecord(
        id: 'tx-5',
        customerId: 'cust-2',
        type: TransactionType.payment,
        amountPiasters: 6000,
        note: 'paid in full',
        transactionDate: t1,
        createdAt: t1,
        updatedAt: t1,
        deletedAt: null,
        localRevision: 1,
      ),
      // Transaction belonging to soft-deleted customer cust-3-deleted
      BackupTransactionRecord(
        id: 'tx-6-on-deleted-cust',
        customerId: 'cust-3-deleted',
        type: TransactionType.credit,
        amountPiasters: 9500,
        note: 'old balance',
        transactionDate: t0,
        createdAt: t0,
        updatedAt: t0,
        deletedAt: null,
        localRevision: 1,
      ),
    ];

    final auditLogs = [
      BackupAuditLogRecord(
        id: 'audit-1',
        transactionId: 'tx-1',
        action: BackupAuditAction.edit,
        previousType: TransactionType.credit,
        previousAmountPiasters: 20000,
        previousNote: 'sugar only',
        previousTransactionDate: t0,
        createdAt: t1,
        localRevision: 1,
      ),
      BackupAuditLogRecord(
        id: 'audit-2',
        transactionId: 'tx-3-deleted',
        action: BackupAuditAction.delete,
        previousType: TransactionType.credit,
        previousAmountPiasters: 8000,
        previousNote: 'cancelled entry',
        previousTransactionDate: t1,
        createdAt: t2,
        localRevision: 1,
      ),
    ];

    return CloudBackupSnapshot(
      preview: CloudBackupSnapshotPreview(
        version: version,
        ownerUserId: ownerId,
        activeDeviceId: activeDeviceId,
        confirmedAt: confirmed,
        customerCount: 2,
        deletedCustomerCount: 1,
        transactionCount: 5,
        deletedTransactionCount: 1,
        auditLogCount: 2,
      ),
      customers: customers,
      transactions: transactions,
      auditLogs: auditLogs,
    );
  }

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'daftari_drift_restore_store_test_',
    );
    databaseFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}daftari_restore.sqlite',
    );
    FlutterSecureStorage.setMockInitialValues({
      LedgerOwnerStorage.ownerKey: ownerUserId,
    });
    SharedPreferences.setMockInitialValues({
      'localeCode': 'ar',
      'themeMode': 'dark',
      'onboardingCompleted': true,
    });
    commitGate = SessionCommitGate();
    authService = _FakeAuthService(
      user: const AuthUser(
        id: ownerUserId,
        email: 'shop@example.com',
        shopName: 'Al-Amana Grocery',
        emailVerified: true,
      ),
      commitGate: commitGate,
    );
    connectivity = _MockConnectivity();
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
    connectivityService = ConnectivityService(connectivity);
    errorHandler = ErrorHandler(
      AppLogger(output: (_) {}, enableCrashReporting: false),
    );
    clock = FakeDateService(DateTime.utc(2026, 11, 25, 12));
    cloudPublisher = FakeBackupCloudPublisher(
      serverTime: DateTime.utc(2026, 11, 25, 12, 5),
    );
  });

  tearDown(() async {
    await authService.dispose();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  ({
    AppDatabase db,
    DriftRestoreLocalStore restoreStore,
    DriftBackupLocalStore backupStore,
    LedgerOwnerStorage ownerStorage,
    BackupDeviceStorage deviceStorage,
    RunBackupUseCase runBackup,
  })
  openSession({
    QueryInterceptor? interceptor,
    FlutterSecureStorage? secureStorage,
    Future<void> Function()? afterDeleteBeforeInsertHook,
    Future<void> Function()? beforeEnterCommitHook,
    Future<void> Function()? afterSqlCommitBeforeOwnerClaimHook,
  }) {
    final QueryExecutor executor = interceptor == null
        ? NativeDatabase(databaseFile)
        : NativeDatabase(databaseFile).interceptWith(interceptor);
    final db = AppDatabase(executor);
    final effectiveSecureStorage =
        secureStorage ?? const FlutterSecureStorage();
    final ownerStorage = LedgerOwnerStorage(effectiveSecureStorage);
    final deviceStorage = BackupDeviceStorage(
      effectiveSecureStorage,
      db.backupDao,
      generateDeviceId: () => receivingDeviceId,
      generateDeviceSecret: () => receivingDeviceSecret,
    );
    final restoreStore = DriftRestoreLocalStore(
      backupDao: db.backupDao,
      authService: authService,
      ownerStorage: ownerStorage,
      deviceStorage: deviceStorage,
      errorHandler: errorHandler,
      commitGate: commitGate,
      afterDeleteBeforeInsertHook: afterDeleteBeforeInsertHook,
      beforeEnterCommitHook: beforeEnterCommitHook,
      afterSqlCommitBeforeOwnerClaimHook: afterSqlCommitBeforeOwnerClaimHook,
    );
    final lock = InMemoryBackupRunLock();
    final backupStore = DriftBackupLocalStore(
      backupDao: db.backupDao,
      authService: authService,
      ownerStorage: ownerStorage,
      deviceStorage: deviceStorage,
      connectivityService: connectivityService,
      errorHandler: errorHandler,
      commitGate: commitGate,
      isBackupRunning: () => lock.isLocked,
    );
    final runBackup = RunBackupUseCase(
      localStore: backupStore,
      cloudPublisher: cloudPublisher,
      runLock: lock,
      dateService: clock,
      generateBatchId: () => 'post-restore-batch-1',
    );
    return (
      db: db,
      restoreStore: restoreStore,
      backupStore: backupStore,
      ownerStorage: ownerStorage,
      deviceStorage: deviceStorage,
      runBackup: runBackup,
    );
  }

  Future<_DatabaseFullDump> dumpDatabase(AppDatabase db) async {
    final customers = await (db.select(
      db.customers,
    )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
    final transactions = await (db.select(
      db.transactions,
    )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
    final auditLogs = await (db.select(
      db.transactionAuditLogs,
    )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
    final inFlightBatch = await db.backupDao.readInFlightBatch();
    final metadata = await db.backupDao.readMetadata();
    final deviceId = await db.backupDao.readDeviceId();
    final pendingChangesCount = await db.backupDao.countPendingChanges();
    return _DatabaseFullDump(
      customers: customers,
      transactions: transactions,
      auditLogs: auditLogs,
      inFlightBatch: inFlightBatch,
      metadata: metadata,
      deviceId: deviceId,
      pendingChangesCount: pendingChangesCount,
    );
  }

  void expectDumpsIdentical(
    _DatabaseFullDump actual,
    _DatabaseFullDump expected,
  ) {
    expect(actual.customers, expected.customers);
    expect(actual.transactions, expected.transactions);
    expect(actual.auditLogs, expected.auditLogs);
    expect(actual.inFlightBatch, expected.inFlightBatch);
    expect(actual.metadata, expected.metadata);
    expect(actual.deviceId, expected.deviceId);
    expect(actual.pendingChangesCount, expected.pendingChangesCount);
  }

  /// Seeds a populated existing installation with active and soft-deleted
  /// records, audit history, unacknowledged local revisions, an in-flight
  /// pending batch, a saved schedule, inactive device marker, device
  /// credentials, PIN, and app preferences.
  Future<void> seedExistingInstallData(AppDatabase db) async {
    final e0 = DateTime.utc(2026, 11, 18, 9);
    final e1 = DateTime.utc(2026, 11, 19, 10);

    await db
        .into(db.customers)
        .insert(
          CustomersCompanion(
            id: const Value('existing-cust-1'),
            name: const Value('Existing Active Customer'),
            phone: const Value('01220001111'),
            notes: const Value('local note'),
            createdAt: Value(e0),
            updatedAt: Value(e1),
            deletedAt: const Value(null),
            localRevision: const Value(3),
            acknowledgedRevision: const Value(2),
            syncedAt: Value(e0),
          ),
        );
    await db
        .into(db.customers)
        .insert(
          CustomersCompanion(
            id: const Value('existing-cust-2-deleted'),
            name: const Value('Existing Deleted Customer'),
            phone: const Value(null),
            notes: const Value(null),
            createdAt: Value(e0),
            updatedAt: Value(e1),
            deletedAt: Value(e1),
            localRevision: const Value(2),
            acknowledgedRevision: const Value(2),
            syncedAt: Value(e1),
          ),
        );

    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion(
            id: const Value('existing-tx-1'),
            customerId: const Value('existing-cust-1'),
            type: const Value(TransactionTypes.credit),
            amountPiasters: const Value(14000),
            note: const Value('local pending edit'),
            transactionDate: Value(e0),
            createdAt: Value(e0),
            updatedAt: Value(e1),
            deletedAt: const Value(null),
            localRevision: const Value(2),
            acknowledgedRevision: const Value(1),
            syncedAt: Value(e0),
          ),
        );
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion(
            id: const Value('existing-tx-2-deleted'),
            customerId: const Value('existing-cust-1'),
            type: const Value(TransactionTypes.payment),
            amountPiasters: const Value(3500),
            note: const Value('local deleted payment'),
            transactionDate: Value(e0),
            createdAt: Value(e0),
            updatedAt: Value(e1),
            deletedAt: Value(e1),
            localRevision: const Value(2),
            acknowledgedRevision: const Value(2),
            syncedAt: Value(e1),
          ),
        );

    await db
        .into(db.transactionAuditLogs)
        .insert(
          TransactionAuditLogsCompanion(
            id: const Value('existing-audit-1'),
            transactionId: const Value('existing-tx-1'),
            action: const Value(TransactionAuditActions.edit),
            previousType: const Value(TransactionTypes.credit),
            previousAmountPiasters: const Value(9000),
            previousNote: const Value('before local edit'),
            previousTransactionDate: Value(e0),
            createdAt: Value(e1),
            localRevision: const Value(1),
            acknowledgedRevision: const Value(0),
            syncedAt: const Value(null),
          ),
        );
    await db
        .into(db.transactionAuditLogs)
        .insert(
          TransactionAuditLogsCompanion(
            id: const Value('existing-audit-2'),
            transactionId: const Value('existing-tx-2-deleted'),
            action: const Value(TransactionAuditActions.delete),
            previousType: const Value(TransactionTypes.payment),
            previousAmountPiasters: const Value(3500),
            previousNote: const Value('local deleted payment'),
            previousTransactionDate: Value(e0),
            createdAt: Value(e1),
            localRevision: const Value(1),
            acknowledgedRevision: const Value(1),
            syncedAt: Value(e1),
          ),
        );

    // Seed a superseded in-flight batch and existing schedule metadata.
    await db
        .into(db.backupInFlightBatches)
        .insert(
          const BackupInFlightBatchesCompanion(
            id: Value(1),
            batchId: Value('superseded-in-flight-batch'),
            ownerUserId: Value(ownerUserId),
            deviceId: Value(receivingDeviceId),
            capturedAtIso: Value('2026-11-19T10:05:00.000Z'),
            payloadJson: Value(
              '{"customers":[],"transactions":[],"audit_logs":[]}',
            ),
          ),
        );
    await db.backupDao.updateScheduleMetadata(
      (_, _) => const BackupMetadataSnapshot(
        schedule: 'weekly',
        lastConfirmedAtIso: '2026-11-18T09:00:00.000Z',
        nextDueAtIso: '2026-11-25T09:00:00.000Z',
        isDeviceActive: false,
      ),
    );
  }

  group('Pre-commit validation of format, ownership, unique IDs, parent references and field values', () {
    test('rejects invalid format, ownership, duplicate IDs, missing parent references and unsupported field values before touching SQLite', () async {
      final session = openSession();
      await session.deviceStorage.getOrCreateIdentity();
      await seedExistingInstallData(session.db);
      final baselineDump = await dumpDatabase(session.db);
      final summary = (await session.restoreStore.readLocalLedgerSummary())
          .getOrElse((_) => throw StateError('failed'));

      RestoreConsentToken validConsent({String version = 'v-3'}) =>
          RestoreConsentToken(
            version: version,
            activeDeviceId: receivingDeviceId,
            confirmedAt: confirmedAt,
            ownerUserId: ownerUserId,
            localDeviceId: receivingDeviceId,
            localRevisionStamp: summary.revisionStamp,
            requiresTakeover: false,
            requiresReplacement: true,
            primaryConfirmed: true,
            replacementConfirmed: true,
          );

      // 1. Raw JSON payload format, unsupported enum values, non-positive amounts/revisions.
      expect(
        () => RestoreSnapshotValidator.parseAndValidatePayload(
          '{not-valid-json',
          expectedOwnerUserId: ownerUserId,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => RestoreSnapshotValidator.parseAndValidatePayload({
          'status': 'ready',
          'owner_user_id': otherUserId,
          'version': 'v-3',
          'active_device_id': receivingDeviceId,
          'confirmed_at': confirmedAt.toIso8601String(),
          'customer_count': 0,
          'deleted_customer_count': 0,
          'transaction_count': 0,
          'deleted_transaction_count': 0,
          'audit_log_count': 0,
          'customers': const <Object?>[],
          'transactions': const <Object?>[],
          'audit_logs': const <Object?>[],
        }, expectedOwnerUserId: ownerUserId),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => RestoreSnapshotValidator.parseAndValidatePayload({
          'status': 'ready',
          'version': 'v-3',
          'active_device_id': receivingDeviceId,
          'confirmed_at': confirmedAt.toIso8601String(),
          'customer_count': 1,
          'deleted_customer_count': 0,
          'transaction_count': 1,
          'deleted_transaction_count': 0,
          'audit_log_count': 0,
          'customers': [
            {
              'id': 'c-1',
              'name': 'Valid',
              'phone': null,
              'notes': null,
              'created_at': confirmedAt.toIso8601String(),
              'updated_at': confirmedAt.toIso8601String(),
              'deleted_at': null,
              'local_revision': 1,
            },
          ],
          'transactions': [
            {
              'id': 't-1',
              'customer_id': 'c-1',
              'type': 'unsupported_type',
              'amount_piasters': 5000,
              'note': null,
              'transaction_date': confirmedAt.toIso8601String(),
              'created_at': confirmedAt.toIso8601String(),
              'updated_at': confirmedAt.toIso8601String(),
              'deleted_at': null,
              'local_revision': 1,
            },
          ],
          'audit_logs': const <Object?>[],
        }, expectedOwnerUserId: ownerUserId),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => RestoreSnapshotValidator.parseAndValidatePayload({
          'status': 'ready',
          'version': 'v-3',
          'active_device_id': receivingDeviceId,
          'confirmed_at': confirmedAt.toIso8601String(),
          'customer_count': 1,
          'deleted_customer_count': 0,
          'transaction_count': 1,
          'deleted_transaction_count': 0,
          'audit_log_count': 1,
          'customers': [
            {
              'id': 'c-1',
              'name': 'Valid',
              'phone': null,
              'notes': null,
              'created_at': confirmedAt.toIso8601String(),
              'updated_at': confirmedAt.toIso8601String(),
              'deleted_at': null,
              'local_revision': 1,
            },
          ],
          'transactions': [
            {
              'id': 't-1',
              'customer_id': 'c-1',
              'type': 'credit',
              'amount_piasters': 5000,
              'note': null,
              'transaction_date': confirmedAt.toIso8601String(),
              'created_at': confirmedAt.toIso8601String(),
              'updated_at': confirmedAt.toIso8601String(),
              'deleted_at': null,
              'local_revision': 1,
            },
          ],
          'audit_logs': [
            {
              'id': 'a-1',
              'transaction_id': 't-1',
              'action': 'unsupported_action',
              'previous_type': 'credit',
              'previous_amount_piasters': 5000,
              'previous_note': null,
              'previous_transaction_date': confirmedAt.toIso8601String(),
              'created_at': confirmedAt.toIso8601String(),
              'local_revision': 1,
            },
          ],
        }, expectedOwnerUserId: ownerUserId),
        throwsA(isA<ValidationException>()),
      );

      final valid = sampleConfirmedSnapshot();

      // 2. Ownership mismatch on snapshot.preview.ownerUserId.
      final wrongOwnerSnapshot = CloudBackupSnapshot(
        preview: valid.preview.copyWith(ownerUserId: otherUserId),
        customers: valid.customers,
        transactions: valid.transactions,
        auditLogs: valid.auditLogs,
      );

      // 3. Duplicate customer ID.
      final duplicateCustomerSnapshot = CloudBackupSnapshot(
        preview: valid.preview.copyWith(
          customerCount: 2,
          deletedCustomerCount: 0,
          transactionCount: 0,
          deletedTransactionCount: 0,
          auditLogCount: 0,
        ),
        customers: [valid.customers[0], valid.customers[0]],
        transactions: const [],
        auditLogs: const [],
      );

      // 4. Duplicate transaction ID.
      final duplicateTransactionSnapshot = CloudBackupSnapshot(
        preview: valid.preview.copyWith(
          customerCount: 1,
          deletedCustomerCount: 0,
          transactionCount: 2,
          deletedTransactionCount: 0,
          auditLogCount: 0,
        ),
        customers: [valid.customers[0]],
        transactions: [valid.transactions[0], valid.transactions[0]],
        auditLogs: const [],
      );

      // 5. Duplicate audit log ID.
      final duplicateAuditSnapshot = CloudBackupSnapshot(
        preview: valid.preview.copyWith(
          customerCount: 1,
          deletedCustomerCount: 0,
          transactionCount: 1,
          deletedTransactionCount: 0,
          auditLogCount: 2,
        ),
        customers: [valid.customers[0]],
        transactions: [valid.transactions[0]],
        auditLogs: [valid.auditLogs[0], valid.auditLogs[0]],
      );

      // 6. Missing parent customer reference on transaction.
      final orphanTransactionSnapshot = CloudBackupSnapshot(
        preview: valid.preview.copyWith(
          customerCount: 1,
          deletedCustomerCount: 0,
          transactionCount: 1,
          deletedTransactionCount: 0,
          auditLogCount: 0,
        ),
        customers: [valid.customers[0]],
        transactions: [
          BackupTransactionRecord(
            id: 'tx-orphan',
            customerId: 'non-existent-customer',
            type: TransactionType.credit,
            amountPiasters: 5000,
            note: null,
            transactionDate: confirmedAt,
            createdAt: confirmedAt,
            updatedAt: confirmedAt,
            deletedAt: null,
            localRevision: 1,
          ),
        ],
        auditLogs: const [],
      );

      // 7. Missing parent transaction reference on audit log.
      final orphanAuditSnapshot = CloudBackupSnapshot(
        preview: valid.preview.copyWith(
          customerCount: 1,
          deletedCustomerCount: 0,
          transactionCount: 1,
          deletedTransactionCount: 0,
          auditLogCount: 1,
        ),
        customers: [valid.customers[0]],
        transactions: [valid.transactions[0]],
        auditLogs: [
          BackupAuditLogRecord(
            id: 'audit-orphan',
            transactionId: 'non-existent-tx',
            action: BackupAuditAction.edit,
            previousType: TransactionType.credit,
            previousAmountPiasters: 5000,
            previousNote: null,
            previousTransactionDate: confirmedAt,
            createdAt: confirmedAt,
            localRevision: 1,
          ),
        ],
      );

      // 8. Blank customer name or whitespace-only optional phone/note.
      final blankNameSnapshot = CloudBackupSnapshot(
        preview: valid.preview.copyWith(
          customerCount: 1,
          deletedCustomerCount: 0,
          transactionCount: 0,
          deletedTransactionCount: 0,
          auditLogCount: 0,
        ),
        customers: [
          BackupCustomerRecord(
            id: 'cust-blank',
            name: '   ',
            phone: null,
            notes: null,
            createdAt: confirmedAt,
            updatedAt: confirmedAt,
            deletedAt: null,
            localRevision: 1,
          ),
        ],
        transactions: const [],
        auditLogs: const [],
      );

      final whitespacePhoneSnapshot = CloudBackupSnapshot(
        preview: valid.preview.copyWith(
          customerCount: 1,
          deletedCustomerCount: 0,
          transactionCount: 0,
          deletedTransactionCount: 0,
          auditLogCount: 0,
        ),
        customers: [
          BackupCustomerRecord(
            id: 'cust-ws-phone',
            name: 'Valid Name',
            phone: '   ',
            notes: null,
            createdAt: confirmedAt,
            updatedAt: confirmedAt,
            deletedAt: null,
            localRevision: 1,
          ),
        ],
        transactions: const [],
        auditLogs: const [],
      );

      // 9. Mismatched preview counts vs actual list lengths.
      final mismatchedCountSnapshot = CloudBackupSnapshot(
        preview: valid.preview.copyWith(customerCount: 99),
        customers: valid.customers,
        transactions: valid.transactions,
        auditLogs: valid.auditLogs,
      );

      for (final invalidSnapshot in [
        wrongOwnerSnapshot,
        duplicateCustomerSnapshot,
        duplicateTransactionSnapshot,
        duplicateAuditSnapshot,
        orphanTransactionSnapshot,
        orphanAuditSnapshot,
        blankNameSnapshot,
        whitespacePhoneSnapshot,
        mismatchedCountSnapshot,
      ]) {
        final res = await session.restoreStore.installConfirmedSnapshot(
          snapshot: invalidSnapshot,
          consent: validConsent(),
        );
        expect(
          res,
          const Left<AppFailure, RestoreLocalInstallResult>(
            AppFailure(AppErrorCode.validation),
          ),
        );
      }

      // Verify the entire database and every backup marker remained untouched.
      final afterFailedValidationsDump = await dumpDatabase(session.db);
      expectDumpsIdentical(afterFailedValidationsDump, baselineDump);
      await session.db.close();
    });
  });

  group('Atomic file-backed Drift replacement, failure injection, reopen comparison, double retry and derived balances', () {
    test('injected failure during replacement rolls back every table and backup marker across reopen, then retry twice succeeds idempotently and preserves balances and device-local settings', () async {
      // 1. Seed file-backed database, device credentials, PIN, and preferences.
      final interceptor = _FailDuringReplacementInsertInterceptor();
      final s1 = openSession(interceptor: interceptor);
      final originalIdentity = await s1.deviceStorage.getOrCreateIdentity();
      expect(originalIdentity.deviceId, receivingDeviceId);
      expect(originalIdentity.deviceSecret, receivingDeviceSecret);

      const secureStorage = FlutterSecureStorage();
      await secureStorage.write(
        key: SecureStorageService.recordKey,
        value: '{"pin":"pin-hash-1","salt":"pin-salt-1"}',
      );
      final prefs = await SharedPreferences.getInstance();
      final localStorage = LocalStorageService(prefs);
      expect(localStorage.localeCode, 'ar');
      expect(localStorage.themeMode, ThemeMode.dark);

      await seedExistingInstallData(s1.db);
      interceptor.failOnTable = 'transactions';
      final baselineDump = await dumpDatabase(s1.db);
      expect(baselineDump.customers, hasLength(2));
      expect(baselineDump.transactions, hasLength(2));
      expect(baselineDump.auditLogs, hasLength(2));
      expect(baselineDump.inFlightBatch, isNotNull);
      expect(baselineDump.metadata.isDeviceActive, isFalse);
      expect(baselineDump.metadata.schedule, 'weekly');
      expect(baselineDump.pendingChangesCount, 3);

      final preSummary = (await s1.restoreStore.readLocalLedgerSummary())
          .getOrElse((_) => throw StateError('failed'));
      expect(preSummary.isPopulated, isTrue);
      expect(preSummary.customerCount, 1);
      expect(preSummary.deletedCustomerCount, 1);
      expect(preSummary.transactionCount, 1);
      expect(preSummary.deletedTransactionCount, 1);
      expect(preSummary.auditLogCount, 2);
      expect(preSummary.pendingChangesCount, 3);

      final snapshot = sampleConfirmedSnapshot();
      final consent = RestoreConsentToken(
        version: snapshot.preview.version,
        activeDeviceId: oldActiveDeviceId,
        confirmedAt: snapshot.preview.confirmedAt,
        ownerUserId: ownerUserId,
        localDeviceId: receivingDeviceId,
        localRevisionStamp: preSummary.revisionStamp,
        requiresTakeover: true,
        requiresReplacement: true,
        primaryConfirmed: true,
        replacementConfirmed: true,
      );

      // 2. Attempt replacement with injected SQLite failure during `transactions` insert
      //    (after all existing audit logs, transactions, customers, and in-flight batches
      //    were deleted and replacement customers were inserted).
      final failedAttempt = await s1.restoreStore.installConfirmedSnapshot(
        snapshot: snapshot,
        consent: consent,
      );
      expect(
        failedAttempt,
        const Left<AppFailure, RestoreLocalInstallResult>(
          AppFailure(AppErrorCode.database),
        ),
      );
      expect(interceptor.failedAttempts, 1);
      await s1.db.close();

      // 3. Reopen the file-backed Drift database from disk and compare EVERY table
      //    and backup marker against the pre-restore baseline.
      final sReopenedAfterFail = openSession();
      final dumpAfterFail = await dumpDatabase(sReopenedAfterFail.db);
      expectDumpsIdentical(dumpAfterFail, baselineDump);
      final summaryAfterFail =
          (await sReopenedAfterFail.restoreStore.readLocalLedgerSummary())
              .getOrElse((_) => throw StateError('failed'));
      expect(summaryAfterFail, preSummary);
      await sReopenedAfterFail.db.close();

      // 4. Retry #1 without injected fault -> atomic installation commits cleanly.
      final sRetry1 = openSession();
      final retry1Result = (await sRetry1.restoreStore.installConfirmedSnapshot(
        snapshot: snapshot,
        consent: consent,
      )).getOrElse((_) => throw StateError('failed'));
      expect(retry1Result, isA<RestoreLocalInstallApplied>());
      final applied1 = retry1Result as RestoreLocalInstallApplied;
      expect(applied1.localLedger.customerCount, 2);
      expect(applied1.localLedger.deletedCustomerCount, 1);
      expect(applied1.localLedger.transactionCount, 5);
      expect(applied1.localLedger.deletedTransactionCount, 1);
      expect(applied1.localLedger.auditLogCount, 2);
      expect(applied1.localLedger.pendingChangesCount, 0);
      expect(applied1.localLedger.isActiveDevice, isTrue);
      expect(applied1.scheduleState.schedule, BackupSchedule.weekly);
      expect(applied1.scheduleState.lastConfirmedAt, confirmedAt);
      expect(
        applied1.scheduleState.nextDueAt,
        confirmedAt.add(const Duration(days: 7)),
      );
      final dumpAfterRetry1 = await dumpDatabase(sRetry1.db);
      await sRetry1.db.close();

      // 5. Retry #2 (reopen database and repeat the exact restore installation).
      final sRetry2 = openSession();
      final postRetry1Summary =
          (await sRetry2.restoreStore.readLocalLedgerSummary()).getOrElse(
            (_) => throw StateError('failed'),
          );
      final repeatConsent = RestoreConsentToken(
        version: snapshot.preview.version,
        activeDeviceId: receivingDeviceId,
        confirmedAt: snapshot.preview.confirmedAt,
        ownerUserId: ownerUserId,
        localDeviceId: receivingDeviceId,
        localRevisionStamp: postRetry1Summary.revisionStamp,
        requiresTakeover: false,
        requiresReplacement: true,
        primaryConfirmed: true,
        replacementConfirmed: true,
      );
      final retry2Result = (await sRetry2.restoreStore.installConfirmedSnapshot(
        snapshot: snapshot,
        consent: repeatConsent,
      )).getOrElse((_) => throw StateError('failed'));
      expect(retry2Result, isA<RestoreLocalInstallApplied>());
      final dumpAfterRetry2 = await dumpDatabase(sRetry2.db);
      expectDumpsIdentical(dumpAfterRetry2, dumpAfterRetry1);

      // 6. Verify every table, revision, timestamp, tombstone, audit log, and
      //    backup marker after reopening from disk.
      expect(dumpAfterRetry2.pendingChangesCount, 0);
      expect(dumpAfterRetry2.inFlightBatch, isNull);
      expect(dumpAfterRetry2.metadata.isDeviceActive, isTrue);
      expect(
        dumpAfterRetry2.metadata.lastConfirmedAtIso,
        confirmedAt.toIso8601String(),
      );
      expect(dumpAfterRetry2.metadata.schedule, 'weekly');
      expect(dumpAfterRetry2.deviceId, receivingDeviceId);

      // Every restored customer, transaction, and audit log is already acknowledged.
      for (final c in dumpAfterRetry2.customers) {
        expect(c.acknowledgedRevision, c.localRevision);
        expect(c.syncedAt?.toUtc(), confirmedAt);
      }
      for (final t in dumpAfterRetry2.transactions) {
        expect(t.acknowledgedRevision, t.localRevision);
        expect(t.syncedAt?.toUtc(), confirmedAt);
      }
      for (final a in dumpAfterRetry2.auditLogs) {
        expect(a.acknowledgedRevision, a.localRevision);
        expect(a.syncedAt?.toUtc(), confirmedAt);
      }

      // Restored history produced ZERO new audit entries (exact 2 audit entries from snapshot).
      expect(dumpAfterRetry2.auditLogs.map((a) => a.id).toList(), [
        'audit-1',
        'audit-2',
      ]);
      final tx1Audits = await sRetry2.db.transactionDao.getAuditLogs('tx-1');
      expect(tx1Audits.single.id, 'audit-1');
      expect(tx1Audits.single.previousAmountPiasters, 20000);
      final tx3Audits = await sRetry2.db.transactionDao.getAuditLogs(
        'tx-3-deleted',
      );
      expect(tx3Audits.single.id, 'audit-2');
      expect(tx3Audits.single.action, TransactionAuditActions.delete);

      // Tombstones are preserved in SQLite when queried with includeDeleted: true,
      // and hidden from active queries.
      final activeCusts = await sRetry2.db.customerDao.getActiveCustomers();
      expect(activeCusts.map((c) => c.id).toSet(), {'cust-1', 'cust-2'});
      final tombstoneCust = await sRetry2.db.customerDao.getCustomerById(
        'cust-3-deleted',
        includeDeleted: true,
      );
      expect(tombstoneCust, isNotNull);
      expect(tombstoneCust!.deletedAt, isNotNull);
      expect(tombstoneCust.localRevision, 3);

      final tombstoneTx = await sRetry2.db.transactionDao.getTransactionById(
        'tx-3-deleted',
        includeDeleted: true,
      );
      expect(tombstoneTx, isNotNull);
      expect(tombstoneTx!.deletedAt, isNotNull);
      expect(tombstoneTx.amountPiasters, 8000);

      // 7. Verify derived customer balances and dashboard totals.
      // cust-1: 30000 (active credit) - 12500 (active payment) = 17500 (ignores 8000 deleted credit)
      expect(await sRetry2.db.customerDao.getCustomerBalance('cust-1'), 17500);
      // cust-2: 6000 (active credit) - 6000 (active payment) = 0
      expect(await sRetry2.db.customerDao.getCustomerBalance('cust-2'), 0);
      // cust-3-deleted: soft-deleted customer balance is 0
      expect(
        await sRetry2.db.customerDao.getCustomerBalance('cust-3-deleted'),
        0,
      );

      final dashboardTotals = await sRetry2.db.customerDao.getDashboardTotals();
      expect(dashboardTotals.activeCustomers, 2);
      expect(dashboardTotals.totalCreditPiasters, 36000);
      expect(dashboardTotals.totalPaymentPiasters, 18500);
      expect(dashboardTotals.balancePiasters, 17500);

      // Device credentials, PIN, and app preferences remained device-local.
      expect(await sRetry2.deviceStorage.readIdentity(), originalIdentity);
      final pinRecordRaw = await secureStorage.read(
        key: SecureStorageService.recordKey,
      );
      expect(pinRecordRaw, '{"pin":"pin-hash-1","salt":"pin-salt-1"}');
      expect(localStorage.localeCode, 'ar');
      expect(localStorage.themeMode, ThemeMode.dark);

      // 8. After successful restore, next local edit backs up normally under new authority
      //    with zero restored rows re-uploaded.
      await sRetry2.db.transactionDao.editTransaction(
        id: 'tx-1',
        type: TransactionTypes.credit,
        amountPiasters: 35000,
        transactionDate: DateTime.utc(2026, 11, 20, 8),
        note: 'edited after restore',
      );
      expect(await sRetry2.db.backupDao.countPendingChanges(), 2);

      final backupOutcome = (await sRetry2.runBackup(
        trigger: BackupTrigger.manual,
      )).getOrElse((_) => throw StateError('backup failed'));
      expect(backupOutcome, isA<BackupRunConfirmed>());
      expect(cloudPublisher.publishedBatches, hasLength(1));
      final uploadedBatch = cloudPublisher.publishedBatches.single;
      expect(uploadedBatch.deviceId, receivingDeviceId);
      expect(uploadedBatch.customers, isEmpty);
      expect(uploadedBatch.transactions.map((t) => t.id), ['tx-1']);
      expect(uploadedBatch.transactions.single.amountPiasters, 35000);
      expect(uploadedBatch.transactions.single.localRevision, 3);
      expect(uploadedBatch.auditLogs, hasLength(1));
      expect(uploadedBatch.auditLogs.single.previousAmountPiasters, 30000);
      expect(await sRetry2.db.backupDao.countPendingChanges(), 0);

      await sRetry2.db.close();
    });

    test('rechecks local ownership, local revision stamp and live session before committing replacement', () async {
      final s1 = openSession();
      await s1.deviceStorage.getOrCreateIdentity();
      await seedExistingInstallData(s1.db);
      final baselineDump = await dumpDatabase(s1.db);
      final initialSummary = (await s1.restoreStore.readLocalLedgerSummary())
          .getOrElse((_) => throw StateError('failed'));
      final snapshot = sampleConfirmedSnapshot();

      final consent = RestoreConsentToken(
        version: snapshot.preview.version,
        activeDeviceId: receivingDeviceId,
        confirmedAt: snapshot.preview.confirmedAt,
        ownerUserId: ownerUserId,
        localDeviceId: receivingDeviceId,
        localRevisionStamp: initialSummary.revisionStamp,
        requiresTakeover: false,
        requiresReplacement: true,
        primaryConfirmed: true,
        replacementConfirmed: true,
      );

      // 1. Local edit occurs after preview/consent -> blocks with RestoreLocalInstallBlockedLocalLedgerChanged.
      await s1.db.customerDao.createCustomer(name: 'New Local Customer');
      final afterEditDump = await dumpDatabase(s1.db);

      final staleRevisionResult =
          (await s1.restoreStore.installConfirmedSnapshot(
            snapshot: snapshot,
            consent: consent,
          )).getOrElse((_) => throw StateError('failed'));
      expect(
        staleRevisionResult,
        isA<RestoreLocalInstallBlockedLocalLedgerChanged>().having(
          (r) => r.updatedLocalLedger.customerCount,
          'customerCount',
          2,
        ),
      );
      expectDumpsIdentical(await dumpDatabase(s1.db), afterEditDump);

      // 2. Different linked owner in LedgerOwnerStorage -> blocks with RestoreLocalInstallBlockedAccountMismatch.
      final updatedSummary = (await s1.restoreStore.readLocalLedgerSummary())
          .getOrElse((_) => throw StateError('failed'));
      await const FlutterSecureStorage().write(
        key: LedgerOwnerStorage.ownerKey,
        value: otherUserId,
      );
      final mismatchResult = (await s1.restoreStore.installConfirmedSnapshot(
        snapshot: snapshot,
        consent: RestoreConsentToken(
          version: snapshot.preview.version,
          activeDeviceId: receivingDeviceId,
          confirmedAt: snapshot.preview.confirmedAt,
          ownerUserId: ownerUserId,
          localDeviceId: receivingDeviceId,
          localRevisionStamp: updatedSummary.revisionStamp,
          requiresTakeover: false,
          requiresReplacement: true,
          primaryConfirmed: true,
          replacementConfirmed: true,
        ),
      )).getOrElse((_) => throw StateError('failed'));
      expect(mismatchResult, isA<RestoreLocalInstallBlockedAccountMismatch>());
      expectDumpsIdentical(await dumpDatabase(s1.db), afterEditDump);
      await const FlutterSecureStorage().write(
        key: LedgerOwnerStorage.ownerKey,
        value: ownerUserId,
      );
      await s1.db.close();

      // 3. Sign-out before commit gate rolls back SQLite transaction and preserves ledger.
      final sSignOut = openSession(
        beforeEnterCommitHook: () async {
          await authService.signOut();
        },
      );
      final signOutResult =
          (await sSignOut.restoreStore.installConfirmedSnapshot(
            snapshot: snapshot,
            consent: RestoreConsentToken(
              version: snapshot.preview.version,
              activeDeviceId: receivingDeviceId,
              confirmedAt: snapshot.preview.confirmedAt,
              ownerUserId: ownerUserId,
              localDeviceId: receivingDeviceId,
              localRevisionStamp: updatedSummary.revisionStamp,
              requiresTakeover: false,
              requiresReplacement: true,
              primaryConfirmed: true,
              replacementConfirmed: true,
            ),
          )).getOrElse((_) => throw StateError('failed'));
      expect(
        signOutResult,
        isA<RestoreLocalInstallBlockedSessionInvalidated>(),
      );
      expect(
        (await dumpDatabase(sSignOut.db)).customers.length,
        baselineDump.customers.length + 1,
      );
      await sSignOut.db.close();
    });

    test('P13-03: unlinked receiving phone makes ownership durable across SQLite commit when owner write fails or process interrupts immediately after SQLite commit', () async {
      // Start with an unlinked receiving phone (no ownerKey in FlutterSecureStorage).
      await const FlutterSecureStorage().delete(
        key: LedgerOwnerStorage.ownerKey,
      );
      final snapshot = sampleConfirmedSnapshot();

      // 1. Subcase A: Interrupt immediately after SQLite commit (before
      // secure-storage owner write is called).
      final sInterrupt = openSession(
        afterSqlCommitBeforeOwnerClaimHook: () async {
          throw const StorageException();
        },
      );
      await sInterrupt.deviceStorage.getOrCreateIdentity();
      final emptySummary =
          (await sInterrupt.restoreStore.readLocalLedgerSummary()).getOrElse(
            (_) => throw StateError('failed'),
          );
      expect(emptySummary.linkedOwnerUserId, isNull);

      final consent = RestoreConsentToken(
        version: snapshot.preview.version,
        activeDeviceId: receivingDeviceId,
        confirmedAt: snapshot.preview.confirmedAt,
        ownerUserId: ownerUserId,
        localDeviceId: receivingDeviceId,
        localRevisionStamp: emptySummary.revisionStamp,
        requiresTakeover: false,
        requiresReplacement: false,
        primaryConfirmed: true,
        replacementConfirmed: false,
      );

      final interruptedInstall = await sInterrupt.restoreStore
          .installConfirmedSnapshot(snapshot: snapshot, consent: consent);
      expect(interruptedInstall.isLeft(), isTrue);
      final dumpAfterSqlCommit = await dumpDatabase(sInterrupt.db);
      expect(dumpAfterSqlCommit.customers.length, 3);
      await sInterrupt.db.close();

      // Reopen and switch to otherUserId -> only ownerUserId can own or
      // publish the restored rows even though secure storage was never written!
      authService.signIn(
        const AuthUser(
          id: otherUserId,
          email: 'other@example.com',
          shopName: 'Other Shop',
          emailVerified: true,
        ),
      );
      final sOther1 = openSession();
      expect(await sOther1.ownerStorage.readOwnerId(), ownerUserId);
      expect(await sOther1.ownerStorage.claimOwnerId(otherUserId), ownerUserId);
      final otherSummary1 =
          (await sOther1.restoreStore.readLocalLedgerSummary()).getOrElse(
            (_) => throw StateError('failed'),
          );
      expect(otherSummary1.linkedOwnerUserId, ownerUserId);
      expect(otherSummary1.isAccountMismatchFor(otherUserId), isTrue);

      // Other account cannot publish the restored rows (even if a local edit exists).
      await sOther1.db.customerDao.createCustomer(
        name: 'Pending Edit While Other User Signed In',
      );
      final otherPublish1 = (await sOther1.runBackup(
        trigger: BackupTrigger.manual,
      )).getOrElse((_) => throw StateError('failed'));
      expect(
        otherPublish1,
        isA<BackupRunSkipped>().having(
          (r) => r.reason,
          'reason',
          BackupIneligibilityReason.accountMismatch,
        ),
      );
      expect(cloudPublisher.publishedBatches, isEmpty);
      await sOther1.db.close();

      // 2. Subcase B: Reset database to unlinked empty state, then fail the
      // secure-storage owner write itself after SQLite commit.
      if (await databaseFile.exists()) {
        await databaseFile.delete();
      }
      await const FlutterSecureStorage().delete(
        key: LedgerOwnerStorage.ownerKey,
      );
      authService.signIn(
        const AuthUser(
          id: ownerUserId,
          email: 'shop@example.com',
          shopName: 'Al-Amana Grocery',
          emailVerified: true,
        ),
      );

      final failingOwnerStorage = _MockSecureStorage();
      when(() => failingOwnerStorage.read(key: any(named: 'key')))
          .thenAnswer((invocation) async {
            final key = invocation.namedArguments[#key] as String?;
            if (key == BackupDeviceStorage.secretKeyFor(receivingDeviceId)) {
              return receivingDeviceSecret;
            }
            return null;
          });
      when(
        () => failingOwnerStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String?;
        if (key == LedgerOwnerStorage.ownerKey) {
          throw PlatformException(
            code: 'write_failed',
            message: 'Simulated secure storage write failure',
          );
        }
      });

      final sFailOwnerWrite = openSession(secureStorage: failingOwnerStorage);
      late final RestoreConsentToken consent2;
      late final _DatabaseFullDump committedDump;
      try {
        await sFailOwnerWrite.deviceStorage.getOrCreateIdentity();
        final emptySummary2 =
            (await sFailOwnerWrite.restoreStore.readLocalLedgerSummary())
                .getOrElse((_) => throw StateError('failed'));

        consent2 = RestoreConsentToken(
          version: snapshot.preview.version,
          activeDeviceId: receivingDeviceId,
          confirmedAt: snapshot.preview.confirmedAt,
          ownerUserId: ownerUserId,
          localDeviceId: receivingDeviceId,
          localRevisionStamp: emptySummary2.revisionStamp,
          requiresTakeover: false,
          requiresReplacement: false,
          primaryConfirmed: true,
          replacementConfirmed: false,
        );
        final failedOwnerWriteInstall = await sFailOwnerWrite.restoreStore
            .installConfirmedSnapshot(snapshot: snapshot, consent: consent2);
        expect(failedOwnerWriteInstall.isLeft(), isTrue);
        committedDump = await dumpDatabase(sFailOwnerWrite.db);
      } finally {
        await sFailOwnerWrite.db.close();
      }

      // Reopen with otherUserId while secure storage still has no ownerKey:
      // durable SQLite owner binding still blocks otherUserId from claiming
      // or publishing the restored rows!
      FlutterSecureStorage.setMockInitialValues({
        BackupDeviceStorage.secretKeyFor(receivingDeviceId):
            receivingDeviceSecret,
      });
      authService.signIn(
        const AuthUser(
          id: otherUserId,
          email: 'other@example.com',
          shopName: 'Other Shop',
          emailVerified: true,
        ),
      );

      final sOther2 = openSession();
      expect(await sOther2.ownerStorage.readOwnerId(), ownerUserId);
      expect(await sOther2.ownerStorage.claimOwnerId(otherUserId), ownerUserId);
      final otherEligibility =
          (await sOther2.backupStore.readEligibilityContext()).getOrElse(
            (_) => throw StateError('failed'),
          );
      expect(otherEligibility.linkedOwnerUserId, ownerUserId);
      expect(otherEligibility.isMatchingLinkedAccount, isFalse);
      await sOther2.db.close();

      // Switch back to ownerUserId, retry the exact same restore, and compare
      // all rows, audit history, and backup markers.
      authService.signIn(
        const AuthUser(
          id: ownerUserId,
          email: 'shop@example.com',
          shopName: 'Al-Amana Grocery',
          emailVerified: true,
        ),
      );
      final sRetry = openSession();
      final retryResult = (await sRetry.restoreStore.installConfirmedSnapshot(
        snapshot: snapshot,
        consent: consent2,
      )).getOrElse((_) => throw StateError('failed'));
      expect(retryResult, isA<RestoreLocalInstallApplied>());
      expect(await sRetry.ownerStorage.readOwnerId(), ownerUserId);
      expectDumpsIdentical(await dumpDatabase(sRetry.db), committedDump);
      await sRetry.db.close();
    });
  });
}
