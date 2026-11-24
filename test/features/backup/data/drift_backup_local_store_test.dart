import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/connectivity_service.dart';
import 'package:daftariapp/core/services/session_commit_gate.dart';
import 'package:daftariapp/features/auth/session/data/services/ledger_owner_storage.dart';
import 'package:daftariapp/features/auth/session/data/services/secure_gotrue_storage.dart';
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
import 'package:daftariapp/features/backup/domain/usecases/update_backup_schedule_usecase.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../domain/backup_domain_fakes.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.user, this.commitGate});

  final StreamController<AuthSessionEvent> _authController =
      StreamController<AuthSessionEvent>.broadcast();
  final SessionCommitGate? commitGate;

  AuthUser? user;
  final List<String> eventLog = [];

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
      eventLog.add('sign_out_applied');
    }

    final gate = commitGate;
    return gate == null
        ? performSignOut()
        : gate.runSessionInvalidation(performSignOut);
  }

  void switchUser(AuthUser? next) {
    user = next;
    if (next == null) {
      _authController.add(const AuthSessionSignedOut());
    } else {
      _authController.add(AuthSessionSignedIn(next));
    }
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

class _ControllableOwnerStorage extends LedgerOwnerStorage {
  _ControllableOwnerStorage(super.storage);

  Future<void> Function()? beforeReadOwnerId;

  @override
  Future<String?> readOwnerId() async {
    if (beforeReadOwnerId case final hook?) {
      await hook();
    }
    return super.readOwnerId();
  }
}

/// Pauses inside SQLite acknowledgment AFTER pre-write authority checks and
/// row updates have already executed, right on the in-flight batch DELETE
/// statement before SQLite COMMIT.
class _PauseOnInFlightDeleteInterceptor extends QueryInterceptor {
  _PauseOnInFlightDeleteInterceptor({required this.onDeleteInFlightBatch});

  final Future<void> Function() onDeleteInFlightBatch;

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (statement.contains('backup_in_flight_batches')) {
      await onDeleteInFlightBatch();
    }
    return executor.runDelete(statement, args);
  }
}

/// Delays the actual SQLite `COMMIT` after the acknowledgment transaction's
/// callback and final guard have already succeeded, so sign-out serialization
/// against executor commit can be verified directly.
class _DelayAckCommitInterceptor extends QueryInterceptor {
  _DelayAckCommitInterceptor({required this.onCommitAcknowledgment});

  final Future<void> Function() onCommitAcknowledgment;
  bool _sawInFlightDelete = false;

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('backup_in_flight_batches')) {
      _sawInFlightDelete = true;
    }
    return executor.runDelete(statement, args);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    if (_sawInFlightDelete) {
      _sawInFlightDelete = false;
      await onCommitAcknowledgment();
    }
    await inner.send();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ownerUserId = '11111111-1111-4111-8111-111111111111';
  const deviceId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  final deviceSecret = 'a'.padRight(64, '1');

  late Directory tempDirectory;
  late File databaseFile;
  late SessionCommitGate commitGate;
  late _FakeAuthService authService;
  late _MockConnectivity connectivity;
  late ConnectivityService connectivityService;
  late ErrorHandler errorHandler;
  late FakeDateService clock;
  late FakeBackupCloudPublisher cloudPublisher;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'daftari_drift_backup_store_test_',
    );
    databaseFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}daftari_backup.sqlite',
    );
    FlutterSecureStorage.setMockInitialValues({
      LedgerOwnerStorage.ownerKey: ownerUserId,
    });
    commitGate = SessionCommitGate();
    authService = _FakeAuthService(
      user: const AuthUser(
        id: ownerUserId,
        email: 'shop@example.com',
        shopName: 'Daftari Shop',
        emailVerified: true,
      ),
      commitGate: commitGate,
    );
    connectivity = _MockConnectivity();
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
    connectivityService = ConnectivityService(connectivity);
    errorHandler = ErrorHandler(AppLogger(output: (_) {}));
    clock = FakeDateService(DateTime.utc(2026, 11, 24, 10));
    cloudPublisher = FakeBackupCloudPublisher(
      serverTime: DateTime.utc(2026, 11, 24, 10, 0, 5, 123, 456),
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
    DriftBackupLocalStore store,
    InMemoryBackupRunLock lock,
    RunBackupUseCase runBackup,
    UpdateBackupScheduleUseCase updateSchedule,
    _ControllableOwnerStorage ownerStorage,
  })
  openSession({int startBatchIndex = 0, QueryInterceptor? interceptor}) {
    final QueryExecutor executor = interceptor == null
        ? NativeDatabase(databaseFile)
        : NativeDatabase(databaseFile).interceptWith(interceptor);
    final db = AppDatabase(executor);
    final lock = InMemoryBackupRunLock();
    const secureStorage = FlutterSecureStorage();
    final ownerStorage = _ControllableOwnerStorage(secureStorage);
    final deviceStorage = BackupDeviceStorage(
      secureStorage,
      db.backupDao,
      generateDeviceId: () => deviceId,
      generateDeviceSecret: () => deviceSecret,
    );
    final store = DriftBackupLocalStore(
      backupDao: db.backupDao,
      authService: authService,
      ownerStorage: ownerStorage,
      deviceStorage: deviceStorage,
      connectivityService: connectivityService,
      errorHandler: errorHandler,
      commitGate: commitGate,
      isBackupRunning: () => lock.isLocked,
    );
    var counter = startBatchIndex;
    final runBackup = RunBackupUseCase(
      localStore: store,
      cloudPublisher: cloudPublisher,
      runLock: lock,
      dateService: clock,
      generateBatchId: () => 'batch-${++counter}',
    );
    final updateSchedule = UpdateBackupScheduleUseCase(
      localStore: store,
      dateService: clock,
    );
    return (
      db: db,
      store: store,
      lock: lock,
      runBackup: runBackup,
      updateSchedule: updateSchedule,
      ownerStorage: ownerStorage,
    );
  }

  test('first backup of an existing ledger captures customers, transactions, soft deletions and audit history and skips unchanged retries', () async {
    final session = openSession();
    try {
      final activeCustomer = await session.db.customerDao.createCustomer(
        name: 'Mona',
        phone: '01012345678',
      );
      final archivedCustomer = await session.db.customerDao.createCustomer(
        name: 'Old Client',
      );
      await session.db.customerDao.softDeleteCustomer(archivedCustomer.id);

      final tx1 = await session.db.transactionDao.createTransaction(
        customerId: activeCustomer.id,
        type: TransactionTypes.credit,
        amountPiasters: 10000,
        note: 'initial',
      );
      await session.db.transactionDao.editTransaction(
        id: tx1.id,
        type: TransactionTypes.credit,
        amountPiasters: 12500,
        transactionDate: tx1.transactionDate,
        note: 'revised',
      );
      final tx2 = await session.db.transactionDao.createTransaction(
        customerId: activeCustomer.id,
        type: TransactionTypes.payment,
        amountPiasters: 3000,
      );
      await session.db.transactionDao.softDeleteTransaction(tx2.id);

      final beforeContext = await session.store.readEligibilityContext();
      expect(
        beforeContext
            .getOrElse((_) => throw StateError('failed'))
            .pendingChangesCount,
        6,
      );

      final firstResult = await session.runBackup(
        trigger: BackupTrigger.manual,
      );
      expect(firstResult.isRight(), isTrue);
      final confirmed = firstResult.getOrElse(
        (_) => throw StateError('failed'),
      ) as BackupRunConfirmed;
      expect(confirmed.summary.acknowledgedRecordCount, 6);
      expect(confirmed.summary.remainingPendingCount, 0);
      expect(confirmed.summary.confirmedAt, cloudPublisher.serverTime);

      expect(
        cloudPublisher.cloudCustomers.keys,
        containsAll([activeCustomer.id, archivedCustomer.id]),
      );
      expect(
        cloudPublisher.cloudCustomers[archivedCustomer.id]!.isDeleted,
        isTrue,
      );
      expect(cloudPublisher.cloudTransactions[tx1.id]!.amountPiasters, 12500);
      expect(cloudPublisher.cloudTransactions[tx2.id]!.isDeleted, isTrue);
      expect(cloudPublisher.cloudAuditLogs, hasLength(2));
      expect(await session.db.backupDao.readInFlightBatch(), isNull);

      final secondResult = await session.runBackup(
        trigger: BackupTrigger.manual,
      );
      expect(
        secondResult,
        Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.noPendingChanges,
            scheduleState: confirmed.scheduleState,
          ),
        ),
      );
      expect(cloudPublisher.publishAttempts, 1);
    } finally {
      await session.db.close();
    }
  });

  test('editing tx 100 -> 150 and adding a transaction during upload keeps edit, new tx and audit log pending in SQLite for next batch', () async {
    final session = openSession();
    try {
      final customer = await session.db.customerDao.createCustomer(
        name: 'Khaled',
      );
      final tx1 = await session.db.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 10000,
      );

      final uploadStarted = Completer<void>();
      final releaseUpload = Completer<void>();
      cloudPublisher.onPublishStarted = (_) async {
        if (!uploadStarted.isCompleted) {
          uploadStarted.complete();
          await releaseUpload.future;
        }
      };

      final firstRunFuture = session.runBackup(trigger: BackupTrigger.manual);
      await uploadStarted.future;

      await session.db.transactionDao.editTransaction(
        id: tx1.id,
        type: TransactionTypes.credit,
        amountPiasters: 15000,
        transactionDate: tx1.transactionDate,
        note: 'edited during upload',
      );
      final tx2 = await session.db.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.payment,
        amountPiasters: 4000,
      );

      releaseUpload.complete();
      final firstRun = await firstRunFuture;
      final firstConfirmed = firstRun.getOrElse(
        (_) => throw StateError('failed'),
      ) as BackupRunConfirmed;

      expect(firstConfirmed.summary.acknowledgedRecordCount, 1);
      expect(firstConfirmed.summary.remainingPendingCount, 3);
      expect(cloudPublisher.cloudTransactions[tx1.id]!.amountPiasters, 10000);

      final localTx1 = await session.db.transactionDao.getTransactionById(
        tx1.id,
      );
      expect(localTx1!.amountPiasters, 15000);
      expect(localTx1.localRevision, 2);
      expect(localTx1.acknowledgedRevision, 1);

      cloudPublisher.onPublishStarted = null;
      cloudPublisher.serverTime = DateTime.utc(2026, 11, 24, 10, 5);
      final secondRun = await session.runBackup(trigger: BackupTrigger.manual);
      final secondConfirmed = secondRun.getOrElse(
        (_) => throw StateError('failed'),
      ) as BackupRunConfirmed;
      expect(secondConfirmed.summary.acknowledgedRecordCount, 3);
      expect(secondConfirmed.summary.remainingPendingCount, 0);

      final secondBatch = cloudPublisher.publishedBatches[1];
      expect(secondBatch.customers, isEmpty);
      expect(secondBatch.transactions.map((t) => t.id).toSet(), {
        tx1.id,
        tx2.id,
      });
      expect(cloudPublisher.cloudTransactions[tx1.id]!.amountPiasters, 15000);
      expect(cloudPublisher.cloudTransactions[tx2.id]!.amountPiasters, 4000);
      expect(cloudPublisher.cloudAuditLogs, hasLength(1));
      expect(
        cloudPublisher.cloudAuditLogs.values.single.previousAmountPiasters,
        10000,
      );
    } finally {
      await session.db.close();
    }
  });

  test('soft-deleting a transaction during upload keeps tombstone and delete audit log pending together while ledger remains usable offline', () async {
    final session = openSession();
    try {
      final customer = await session.db.customerDao.createCustomer(
        name: 'Nadia',
      );
      final tx = await session.db.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 8000,
      );

      final uploadStarted = Completer<void>();
      final releaseUpload = Completer<void>();
      cloudPublisher.onPublishStarted = (_) async {
        if (!uploadStarted.isCompleted) {
          uploadStarted.complete();
          await releaseUpload.future;
        }
      };

      final firstRunFuture = session.runBackup(trigger: BackupTrigger.manual);
      await uploadStarted.future;

      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);
      expect(
        await session.db.transactionDao.softDeleteTransaction(tx.id),
        isTrue,
      );
      expect(await session.db.customerDao.getCustomerBalance(customer.id), 0);

      releaseUpload.complete();
      final firstRun = await firstRunFuture;
      expect(firstRun.isRight(), isTrue);
      expect(cloudPublisher.cloudTransactions[tx.id]!.isDeleted, isFalse);
      expect(await session.db.backupDao.countPendingChanges(), 2);

      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);
      cloudPublisher.onPublishStarted = null;
      cloudPublisher.serverTime = DateTime.utc(2026, 11, 24, 10, 8);

      final secondRun = await session.runBackup(trigger: BackupTrigger.manual);
      expect(secondRun.isRight(), isTrue);
      final secondBatch = cloudPublisher.publishedBatches[1];
      expect(secondBatch.transactions.single.id, tx.id);
      expect(secondBatch.transactions.single.isDeleted, isTrue);
      expect(secondBatch.auditLogs.single.transactionId, tx.id);
      expect(secondBatch.auditLogs.single.action, BackupAuditAction.delete);
      expect(await session.db.backupDao.countPendingChanges(), 0);
    } finally {
      await session.db.close();
    }
  });

  test('interruption before publication survives process restart with original immutable batch and preserves previous cloud contents', () async {
    final initialConfirmed = DateTime.utc(2026, 11, 23, 9, 0, 0, 250);
    late String txId;

    final process1 = openSession();
    try {
      await process1.updateSchedule(BackupSchedule.daily);
      final customer = await process1.db.customerDao.createCustomer(
        name: 'Tarek',
      );
      final tx = await process1.db.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 10000,
      );
      txId = tx.id;

      cloudPublisher.serverTime = initialConfirmed;
      expect(
        (await process1.runBackup(trigger: BackupTrigger.manual)).isRight(),
        isTrue,
      );

      await process1.db.transactionDao.editTransaction(
        id: txId,
        type: TransactionTypes.credit,
        amountPiasters: 15000,
        transactionDate: tx.transactionDate,
      );

      cloudPublisher.nextFailure = const AppFailure(AppErrorCode.network);
      final failed = await process1.runBackup(trigger: BackupTrigger.manual);
      expect(
        failed,
        const Left<AppFailure, BackupRunResult>(
          AppFailure(AppErrorCode.network),
        ),
      );
      expect(cloudPublisher.cloudTransactions[txId]!.amountPiasters, 10000);
      expect(cloudPublisher.distinctServerCommits, 1);

      await process1.db.transactionDao.editTransaction(
        id: txId,
        type: TransactionTypes.credit,
        amountPiasters: 20000,
        transactionDate: tx.transactionDate,
      );
    } finally {
      await process1.db.close();
    }

    cloudPublisher.nextFailure = null;
    final recoveredConfirmTime = DateTime.utc(2026, 11, 24, 11, 0, 0, 500);
    cloudPublisher.serverTime = recoveredConfirmTime;
    final process2 = openSession(startBatchIndex: 100);
    try {
      final scheduleBeforeRetry = (await process2.store.readScheduleState())
          .getOrElse((_) => throw StateError('failed'));
      expect(scheduleBeforeRetry.lastConfirmedAt, initialConfirmed);

      final inFlight = (await process2.store.readInFlightBatch()).getOrElse(
        (_) => throw StateError('failed'),
      );
      expect(inFlight, isNotNull);
      expect(inFlight!.batchId, 'batch-2');
      expect(inFlight.transactions.single.amountPiasters, 15000);
      expect(inFlight.transactions.single.localRevision, 2);

      final retry = await process2.runBackup(trigger: BackupTrigger.manual);
      final confirmed = retry.getOrElse(
        (_) => throw StateError('failed'),
      ) as BackupRunConfirmed;
      expect(confirmed.batchId, 'batch-2');
      expect(cloudPublisher.cloudTransactions[txId]!.amountPiasters, 15000);
      expect(confirmed.summary.remainingPendingCount, 2);

      cloudPublisher.serverTime = DateTime.utc(2026, 11, 24, 11, 5);
      final finalRun = await process2.runBackup(trigger: BackupTrigger.manual);
      expect(finalRun.isRight(), isTrue);
      expect(cloudPublisher.cloudTransactions[txId]!.amountPiasters, 20000);
      expect(cloudPublisher.cloudAuditLogs, hasLength(2));
      expect(await process2.db.backupDao.countPendingChanges(), 0);
    } finally {
      await process2.db.close();
    }
  });

  test('interruption after publication before acknowledgment recovers original confirmation across real process restart with zero duplicate commits or audits', () async {
    final originalServerConfirmation = DateTime.utc(
      2026,
      11,
      24,
      10,
      0,
      5,
      789,
      123,
    );
    late String txId;

    final process1 = openSession();
    try {
      await process1.updateSchedule(BackupSchedule.daily);
      final customer = await process1.db.customerDao.createCustomer(
        name: 'Youssef',
      );
      final tx = await process1.db.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 10000,
      );
      txId = tx.id;

      cloudPublisher.serverTime = originalServerConfirmation;
      var readCount = 0;
      process1.ownerStorage.beforeReadOwnerId = () async {
        readCount++;
        if (readCount == 3) {
          throw const StorageException();
        }
      };

      final interrupted = await process1.runBackup(
        trigger: BackupTrigger.manual,
      );
      expect(
        interrupted,
        const Left<AppFailure, BackupRunResult>(
          AppFailure(AppErrorCode.storage),
        ),
      );
      expect(cloudPublisher.distinctServerCommits, 1);
      expect(await process1.db.backupDao.readInFlightBatch(), isNotNull);
      expect(
        (await process1.store.readScheduleState())
            .getOrElse((_) => throw StateError('failed'))
            .lastConfirmedAt,
        isNull,
      );

      await process1.db.transactionDao.editTransaction(
        id: txId,
        type: TransactionTypes.credit,
        amountPiasters: 15000,
        transactionDate: tx.transactionDate,
      );
    } finally {
      await process1.db.close();
    }

    cloudPublisher.serverTime = DateTime.utc(2026, 11, 24, 12, 0);
    final process2 = openSession(startBatchIndex: 500);
    try {
      final recovered = await process2.runBackup(trigger: BackupTrigger.manual);
      final confirmed = recovered.getOrElse(
        (_) => throw StateError('failed'),
      ) as BackupRunConfirmed;

      expect(confirmed.batchId, 'batch-1');
      expect(confirmed.summary.confirmedAt, originalServerConfirmation);
      expect(
        confirmed.scheduleState.lastConfirmedAt,
        originalServerConfirmation,
      );
      expect(confirmed.summary.remainingPendingCount, 2);
      expect(cloudPublisher.distinctServerCommits, 1);
      expect(cloudPublisher.publishAttempts, 1);
      expect(cloudPublisher.findConfirmationCalls, 1);
      expect(cloudPublisher.cloudTransactions[txId]!.amountPiasters, 10000);
      expect(await process2.db.backupDao.readInFlightBatch(), isNull);

      cloudPublisher.serverTime = DateTime.utc(2026, 11, 24, 12, 5);
      final next = await process2.runBackup(trigger: BackupTrigger.manual);
      expect(next.isRight(), isTrue);
      expect(cloudPublisher.distinctServerCommits, 2);
      expect(cloudPublisher.cloudTransactions[txId]!.amountPiasters, 15000);
      expect(cloudPublisher.cloudAuditLogs, hasLength(1));
      expect(await process2.db.backupDao.countPendingChanges(), 0);
    } finally {
      await process2.db.close();
    }
  });

  test('P12-11: signing out AFTER pre-write guard succeeds and DURING SQLite acknowledgment rolls back every write across database reopen', () async {
    final priorConfirmed = DateTime.utc(2026, 11, 23, 8, 30, 0, 123);
    late String batch2CustomerId;
    late String batch2TxId;

    // Step 1: confirm batch-1 so a prior confirmed timestamp exists.
    final setupSession = openSession();
    try {
      await setupSession.db.customerDao.createCustomer(name: 'Confirmed One');
      cloudPublisher.serverTime = priorConfirmed;
      final first = await setupSession.runBackup(trigger: BackupTrigger.manual);
      expect(first.isRight(), isTrue);
    } finally {
      await setupSession.db.close();
    }

    // Step 2: add new pending records and pause mid-transaction AFTER
    // verifyCommitAllowed succeeds and AFTER customer/transaction UPDATEs
    // have already run inside SQLite, right on backup_in_flight_batches DELETE.
    final midTxPaused = Completer<void>();
    final resumeMidTx = Completer<void>();
    final session = openSession(
      startBatchIndex: 1,
      interceptor: _PauseOnInFlightDeleteInterceptor(
        onDeleteInFlightBatch: () async {
          if (!midTxPaused.isCompleted) {
            midTxPaused.complete();
            await resumeMidTx.future;
          }
        },
      ),
    );
    try {
      final cust = await session.db.customerDao.createCustomer(
        name: 'Pending Two',
      );
      batch2CustomerId = cust.id;
      final tx = await session.db.transactionDao.createTransaction(
        customerId: cust.id,
        type: TransactionTypes.credit,
        amountPiasters: 9000,
      );
      batch2TxId = tx.id;

      cloudPublisher.serverTime = DateTime.utc(2026, 11, 24, 14, 0);
      final runFuture = session.runBackup(trigger: BackupTrigger.manual);
      await midTxPaused.future;

      // Sign out while preserving the ledger owner right in the middle of the
      // SQLite acknowledgment transaction.
      await authService.signOut();
      expect(await session.ownerStorage.readOwnerId(), ownerUserId);

      resumeMidTx.complete();
      final result = await runFuture;
      expect(
        result,
        Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.signedOut,
            scheduleState: BackupScheduleState(lastConfirmedAt: priorConfirmed),
          ),
        ),
      );
    } finally {
      await session.db.close();
    }

    // Step 3: reopen database and verify SQLite rolled back all writes!
    final reopened = openSession();
    try {
      expect(await reopened.db.backupDao.countPendingChanges(), 2);

      final cust = await reopened.db.customerDao.getCustomerById(
        batch2CustomerId,
      );
      expect(cust!.acknowledgedRevision, 0);

      final tx = await reopened.db.transactionDao.getTransactionById(
        batch2TxId,
      );
      expect(tx!.acknowledgedRevision, 0);

      final inFlight = (await reopened.store.readInFlightBatch()).getOrElse(
        (_) => throw StateError('failed'),
      );
      expect(inFlight, isNotNull);
      expect(inFlight!.batchId, 'batch-2');

      final schedule = (await reopened.store.readScheduleState()).getOrElse(
        (_) => throw StateError('failed'),
      );
      expect(schedule.lastConfirmedAt, priorConfirmed);
    } finally {
      await reopened.db.close();
    }
  });

  test('P12-11: delaying executor commit after final guard serializes sign-out strictly after the authorized acknowledgment finishes', () async {
    final confirmedAt = DateTime.utc(2026, 11, 24, 15, 30, 0, 250);
    late String customerId;
    late String txId;

    final commitEntered = Completer<void>();
    final releaseCommit = Completer<void>();
    final session = openSession(
      interceptor: _DelayAckCommitInterceptor(
        onCommitAcknowledgment: () async {
          commitEntered.complete();
          await releaseCommit.future;
        },
      ),
    );
    try {
      final cust = await session.db.customerDao.createCustomer(name: 'Samy');
      customerId = cust.id;
      final tx = await session.db.transactionDao.createTransaction(
        customerId: cust.id,
        type: TransactionTypes.credit,
        amountPiasters: 7500,
      );
      txId = tx.id;

      cloudPublisher.serverTime = confirmedAt;
      final runFuture = session.runBackup(trigger: BackupTrigger.manual);

      // Wait until the callback's final guard passed and Drift is executing COMMIT.
      await commitEntered.future;

      var signOutCompleted = false;
      final signOutFuture = authService.signOut().then((_) {
        signOutCompleted = true;
      });

      // Allow microtasks to pump: sign-out MUST wait for the authorized commit.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(signOutCompleted, isFalse);
      expect(authService.currentUser?.id, ownerUserId);

      // Release the SQLite COMMIT and verify strict ordering.
      releaseCommit.complete();
      final runResult = await runFuture;
      await signOutFuture;

      expect(runResult.isRight(), isTrue);
      expect(
        runResult.getOrElse((_) => throw StateError('failed')),
        isA<BackupRunConfirmed>(),
      );
      expect(signOutCompleted, isTrue);
      expect(authService.currentUser, isNull);
      expect(await session.ownerStorage.readOwnerId(), ownerUserId);
    } finally {
      await session.db.close();
    }

    // Reopen database and confirm authorized revisions, cleared in-flight batch,
    // and server-confirmed timestamp persisted cleanly.
    final reopened = openSession();
    try {
      expect(await reopened.db.backupDao.countPendingChanges(), 0);
      final cust = await reopened.db.customerDao.getCustomerById(customerId);
      expect(cust!.acknowledgedRevision, 1);
      final tx = await reopened.db.transactionDao.getTransactionById(txId);
      expect(tx!.acknowledgedRevision, 1);
      expect(await reopened.db.backupDao.readInFlightBatch(), isNull);
      final schedule = (await reopened.store.readScheduleState()).getOrElse(
        (_) => throw StateError('failed'),
      );
      expect(schedule.lastConfirmedAt, confirmedAt);
    } finally {
      await reopened.db.close();
    }
  });

  test('sign-out right before pre-write acknowledgment guard leaves SQLite revisions, in-flight batch and schedule untouched', () async {
    final session = openSession();
    try {
      final customer = await session.db.customerDao.createCustomer(
        name: 'Hoda',
      );
      await session.db.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 6000,
      );

      final commitReached = Completer<void>();
      final releaseCommit = Completer<void>();
      var readCount = 0;
      session.ownerStorage.beforeReadOwnerId = () async {
        readCount++;
        if (readCount == 3) {
          commitReached.complete();
          await releaseCommit.future;
        }
      };

      final runFuture = session.runBackup(trigger: BackupTrigger.manual);
      await commitReached.future;

      await authService.signOut();
      releaseCommit.complete();

      final result = await runFuture;
      expect(
        result,
        const Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.signedOut,
            scheduleState: BackupScheduleState.initial(),
          ),
        ),
      );
      expect(await session.db.backupDao.countPendingChanges(), 2);
      expect(await session.db.backupDao.readInFlightBatch(), isNotNull);
      expect(
        (await session.store.readScheduleState())
            .getOrElse((_) => throw StateError('failed'))
            .lastConfirmedAt,
        isNull,
      );
    } finally {
      await session.db.close();
    }
  });

  test(
    'account switch right before acknowledgment commit leaves SQLite untouched',
    () async {
      final session = openSession();
      try {
        await session.db.customerDao.createCustomer(name: 'Amr');

        final commitReached = Completer<void>();
        final releaseCommit = Completer<void>();
        var readCount = 0;
        session.ownerStorage.beforeReadOwnerId = () async {
          readCount++;
          if (readCount == 3) {
            commitReached.complete();
            await releaseCommit.future;
          }
        };

        final runFuture = session.runBackup(trigger: BackupTrigger.manual);
        await commitReached.future;

        authService.switchUser(
          const AuthUser(
            id: '22222222-2222-4222-8222-222222222222',
            email: 'other@example.com',
            emailVerified: true,
          ),
        );
        releaseCommit.complete();

        final result = await runFuture;
        expect(
          result,
          const Right<AppFailure, BackupRunResult>(
            BackupRunSkipped(
              reason: BackupIneligibilityReason.accountMismatch,
              scheduleState: BackupScheduleState.initial(),
            ),
          ),
        );
        expect(await session.db.backupDao.countPendingChanges(), 1);
        expect(await session.db.backupDao.readInFlightBatch(), isNotNull);
      } finally {
        await session.db.close();
      }
    },
  );

  test('concurrent Monthly selection queued during paused confirmation commit preserves both Monthly and confirmed timestamp', () async {
    final session = openSession();
    final confirmedAt = DateTime.utc(2026, 1, 31, 14);
    clock.current = confirmedAt;
    try {
      await session.updateSchedule(BackupSchedule.weekly);
      await session.db.customerDao.createCustomer(name: 'Rami');
      cloudPublisher.serverTime = confirmedAt;

      final commitReached = Completer<void>();
      final releaseCommit = Completer<void>();
      var readCount = 0;
      session.ownerStorage.beforeReadOwnerId = () async {
        readCount++;
        if (readCount == 3) {
          commitReached.complete();
          await releaseCommit.future;
        }
      };

      final backupFuture = session.runBackup(trigger: BackupTrigger.manual);
      await commitReached.future;

      final scheduleFuture = session.updateSchedule(BackupSchedule.monthly);
      releaseCommit.complete();

      final backupResult = await backupFuture;
      final scheduleResult = await scheduleFuture;

      expect(backupResult.isRight(), isTrue);
      final finalSchedule = scheduleResult.getOrElse(
        (_) => throw StateError('failed'),
      );
      expect(finalSchedule.schedule, BackupSchedule.monthly);
      expect(finalSchedule.lastConfirmedAt, confirmedAt);
      expect(finalSchedule.nextDueAt, DateTime.utc(2026, 2, 28, 14));
    } finally {
      await session.db.close();
    }
  });

  test('concurrent Monthly schedule selection and confirmation preserve both schedule and confirmed timestamp across restart', () async {
    final process1 = openSession();
    final confirmedAt = DateTime.utc(2026, 1, 31, 14);
    try {
      await process1.updateSchedule(BackupSchedule.weekly);
      await process1.db.customerDao.createCustomer(name: 'Salma');
      cloudPublisher.serverTime = confirmedAt;

      final uploadStarted = Completer<void>();
      final releaseUpload = Completer<void>();
      cloudPublisher.onPublishStarted = (_) async {
        uploadStarted.complete();
        await releaseUpload.future;
      };

      final backupFuture = process1.runBackup(trigger: BackupTrigger.manual);
      await uploadStarted.future;

      final scheduleUpdate = await process1.updateSchedule(
        BackupSchedule.monthly,
      );
      expect(scheduleUpdate.isRight(), isTrue);

      releaseUpload.complete();
      final backupResult = await backupFuture;
      final confirmed = backupResult.getOrElse(
        (_) => throw StateError('failed'),
      ) as BackupRunConfirmed;

      expect(confirmed.scheduleState.schedule, BackupSchedule.monthly);
      expect(confirmed.scheduleState.lastConfirmedAt, confirmedAt);
      expect(confirmed.scheduleState.nextDueAt, DateTime.utc(2026, 2, 28, 14));
    } finally {
      await process1.db.close();
    }

    final process2 = openSession();
    try {
      final persisted = (await process2.store.readScheduleState()).getOrElse(
        (_) => throw StateError('failed'),
      );
      expect(persisted.schedule, BackupSchedule.monthly);
      expect(persisted.lastConfirmedAt, confirmedAt);
      expect(persisted.nextDueAt, DateTime.utc(2026, 2, 28, 14));
    } finally {
      await process2.db.close();
    }
  });

  test('inactive device rejection persists across process restart and blocks subsequent uploads', () async {
    final process1 = openSession();
    try {
      await process1.db.customerDao.createCustomer(name: 'Karim');
      cloudPublisher.rejectAsInactiveDevice = true;

      final rejected = await process1.runBackup(trigger: BackupTrigger.manual);
      expect(
        rejected,
        const Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.inactiveDevice,
            scheduleState: BackupScheduleState.initial(),
          ),
        ),
      );
      expect(cloudPublisher.publishAttempts, 1);
    } finally {
      await process1.db.close();
    }

    final process2 = openSession();
    try {
      final context = (await process2.store.readEligibilityContext()).getOrElse(
        (_) => throw StateError('failed'),
      );
      expect(context.isActiveDevice, isFalse);

      final followUp = await process2.runBackup(trigger: BackupTrigger.manual);
      expect(
        followUp,
        const Right<AppFailure, BackupRunResult>(
          BackupRunSkipped(
            reason: BackupIneligibilityReason.inactiveDevice,
            scheduleState: BackupScheduleState.initial(),
          ),
        ),
      );
      expect(cloudPublisher.publishAttempts, 1);
    } finally {
      await process2.db.close();
    }
  });

  test('P12-16: foreground sign-out and replacement account sign-in after server publication blocks stale worker acknowledgment and preserves in-flight batch and revisions', () async {
    const secureStorage = FlutterSecureStorage();
    const persistedStorage = SecureSupabaseLocalStorage(secureStorage);
    await persistedStorage.persistSession(
      '{"user":{"id":"$ownerUserId","email":"shop@example.com"}}',
    );

    final fgGate = SessionCommitGate(coordinator: null);
    // Shared cross-isolate coordinator simulation between foreground and worker.
    var sharedEpoch = 0;
    var sharedInvalidations = 0;
    var sharedActiveCommits = 0;
    final sharedCoordinator = _InMemoryCrossIsolateCoordinator(
      readEpochFn: () async => sharedEpoch,
      tryEnterCommitFn: (expectedEpoch) async {
        if (sharedInvalidations > 0 || sharedEpoch != expectedEpoch) {
          return false;
        }
        sharedActiveCommits++;
        return true;
      },
      exitCommitFn: () async {
        if (sharedActiveCommits > 0) sharedActiveCommits--;
      },
      beginInvalidationFn: () async {
        sharedInvalidations++;
      },
      endInvalidationFn: () async {
        sharedEpoch++;
        if (sharedInvalidations > 0) sharedInvalidations--;
      },
    );

    final foregroundGate = SessionCommitGate(coordinator: sharedCoordinator);
    final workerGate = SessionCommitGate(coordinator: sharedCoordinator);

    // Worker isolate has its own cached AuthService that still thinks ownerUserId
    // is logged in even after foreground signs out and another account signs in.
    final workerCachedAuth = _FakeAuthService(
      user: const AuthUser(
        id: ownerUserId,
        email: 'shop@example.com',
        shopName: 'Daftari Shop',
        emailVerified: true,
      ),
      commitGate: workerGate,
    );
    addTearDown(workerCachedAuth.dispose);

    final workerDb = AppDatabase(NativeDatabase(databaseFile));
    late String customerId;
    late String txId;
    try {
      final customer = await workerDb.customerDao.createCustomer(
        name: 'P12-16 Customer',
      );
      customerId = customer.id;
      final tx = await workerDb.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 9000,
      );
      txId = tx.id;

      final workerStore = DriftBackupLocalStore(
        backupDao: workerDb.backupDao,
        authService: workerCachedAuth,
        ownerStorage: LedgerOwnerStorage(secureStorage),
        deviceStorage: BackupDeviceStorage(
          secureStorage,
          workerDb.backupDao,
          generateDeviceId: () => deviceId,
          generateDeviceSecret: () => deviceSecret,
        ),
        connectivityService: connectivityService,
        errorHandler: errorHandler,
        commitGate: workerGate,
        hasPersistedSession: persistedStorage.hasAccessToken,
        readPersistedSession: persistedStorage.readSessionSnapshot,
      );
      final workerRunBackup = RunBackupUseCase(
        localStore: workerStore,
        cloudPublisher: cloudPublisher,
        runLock: InMemoryBackupRunLock(),
        dateService: clock,
        generateBatchId: () => 'batch-p12-16',
      );

      final publishedPause = Completer<void>();
      final releaseWorker = Completer<void>();
      cloudPublisher.onPublishStarted = (_) async {
        publishedPause.complete();
        await releaseWorker.future;
      };

      await workerDb.backupDao.updateScheduleMetadata(
        (latest, _) => BackupMetadataSnapshot(
          schedule: BackupSchedule.daily.name,
          lastConfirmedAtIso: null,
          nextDueAtIso: clock
              .now()
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
          isDeviceActive: true,
        ),
      );

      final workerFuture = workerRunBackup(trigger: BackupTrigger.scheduled);
      await publishedPause.future;

      // Foreground signs out ownerUserId AND signs in a different account
      // (while LedgerOwnerStorage remains linked to ownerUserId and workerCachedAuth
      // still caches ownerUserId).
      await foregroundGate.runSessionInvalidation(() async {
        await persistedStorage.removePersistedSession();
      });
      await persistedStorage.persistSession(
        '{"user":{"id":"22222222-2222-4222-8222-222222222222","email":"other@example.com"}}',
      );
      expect(await persistedStorage.hasAccessToken(), isTrue);
      expect(fgGate.isInvalidating, isFalse);

      releaseWorker.complete();
      final result = await workerFuture;
      expect(result.isRight(), isTrue);
      expect(
        result.getOrElse((_) => throw StateError('failed')),
        isA<BackupRunSkipped>(),
      );
    } finally {
      await workerDb.close();
    }

    // Reopen SQLite and assert confirmed time and acknowledged revisions did NOT advance.
    final reopened = openSession();
    try {
      expect(await reopened.db.backupDao.countPendingChanges(), 2);
      final cust = await reopened.db.customerDao.getCustomerById(customerId);
      expect(cust!.acknowledgedRevision, 0);
      final tx = await reopened.db.transactionDao.getTransactionById(txId);
      expect(tx!.acknowledgedRevision, 0);
      final inFlight = await reopened.db.backupDao.readInFlightBatch();
      expect(inFlight, isNotNull);
      expect(inFlight!.batchId, 'batch-p12-16');
      final schedule = (await reopened.store.readScheduleState()).getOrElse(
        (_) => throw StateError('failed'),
      );
      expect(schedule.lastConfirmedAt, isNull);
    } finally {
      await reopened.db.close();
    }
  });
}

class _InMemoryCrossIsolateCoordinator implements SessionCommitCoordinator {
  _InMemoryCrossIsolateCoordinator({
    required this.readEpochFn,
    required this.tryEnterCommitFn,
    required this.exitCommitFn,
    required this.beginInvalidationFn,
    required this.endInvalidationFn,
  });

  final Future<int> Function() readEpochFn;
  final Future<bool> Function(int expectedEpoch) tryEnterCommitFn;
  final Future<void> Function() exitCommitFn;
  final Future<void> Function() beginInvalidationFn;
  final Future<void> Function() endInvalidationFn;

  @override
  Future<int> readEpoch() => readEpochFn();

  @override
  Future<bool> tryEnterCommit({required int expectedEpoch}) =>
      tryEnterCommitFn(expectedEpoch);

  @override
  Future<void> exitCommit() => exitCommitFn();

  @override
  Future<void> beginSessionInvalidation() => beginInvalidationFn();

  @override
  Future<void> endSessionInvalidation() => endInvalidationFn();
}
