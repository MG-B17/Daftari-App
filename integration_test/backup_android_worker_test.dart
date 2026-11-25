import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/connectivity_service.dart';
import 'package:daftariapp/core/services/date_service.dart';
import 'package:daftariapp/core/services/session_commit_gate.dart';
import 'package:daftariapp/features/auth/session/data/services/ledger_owner_storage.dart';
import 'package:daftariapp/features/auth/session/data/services/secure_gotrue_storage.dart';
import 'package:daftariapp/features/auth/session/data/services/supabase_auth_service.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_state.dart';
import 'package:daftariapp/features/backup/data/repositories/drift_backup_local_store.dart';
import 'package:daftariapp/features/backup/data/services/android_backup_platform_bridge.dart';
import 'package:daftariapp/features/backup/data/services/backup_background_worker.dart';
import 'package:daftariapp/features/backup/data/services/backup_device_storage.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_batch.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_run_result.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_schedule.dart';
import 'package:daftariapp/features/backup/domain/repositories/backup_cloud_publisher.dart';
import 'package:daftariapp/features/backup/domain/usecases/run_backup_usecase.dart';
import 'package:daftariapp/features/backup/domain/usecases/update_backup_schedule_usecase.dart';
import 'package:daftariapp/features/backup/presentation/cubit/backup_cubit.dart';
import 'package:daftariapp/features/backup/presentation/models/backup_view_state.dart';
import 'package:daftariapp/features/restore/data/repositories/drift_restore_local_store.dart';
import 'package:daftariapp/features/restore/data/services/restore_transfer_storage.dart';
import 'package:daftariapp/features/restore/domain/entities/restore_entities.dart';
import 'package:daftariapp/features/restore/domain/repositories/restore_local_store.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:integration_test/integration_test.dart';

class _TestForegroundAuthService implements AuthService {
  _TestForegroundAuthService(this._storage, this._commitGate);

  final SecureSupabaseLocalStorage _storage;
  final SessionCommitGate _commitGate;
  AuthUser? _user;

  @override
  bool get isConfigured => true;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthSessionEvent> watchAuthChanges() => const Stream.empty();

  @override
  Future<AuthUser?> getCurrentUser() async {
    final snapshot = await _storage.readSessionSnapshot();
    final id = snapshot?.userId;
    if (id == null || id.isEmpty) {
      _user = null;
      return null;
    }
    _user = AuthUser(
      id: id,
      email: '$id@example.com',
      shopName: 'Worker Test Shop',
      emailVerified: snapshot!.isEmailVerified,
    );
    return _user;
  }

  @override
  Future<void> signOut({String? expectedUserId}) =>
      _commitGate.runSessionInvalidation(() async {
        _user = null;
        await _storage.removePersistedSession();
      });

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
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> resendVerificationEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> updatePassword(String newPassword) => throw UnimplementedError();
}

class _CountingForegroundPublisher implements BackupCloudPublisher {
  int publishCalls = 0;

  @override
  Future<Either<AppFailure, BackupPublicationResult?>> findBatchConfirmation({
    required String batchId,
    required String ownerUserId,
    required String deviceId,
  }) async => const Right(null);

  @override
  Future<Either<AppFailure, BackupPublicationResult>> publishBatch(
    BackupBatch batch,
  ) async {
    publishCalls++;
    return Right(
      BackupPublicationConfirmed(
        batchId: batch.batchId,
        confirmedAt: DateTime.now().toUtc(),
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<void> backupWorkerMain(List<String> args) =>
    runBackupBackgroundWorker(args);

/// Preserves equality check on serialized session strings while reporting only
/// whether the session changed so raw tokens or credentials are never printed
/// on failure (P12-20).
void expectOrdinarySessionUnchanged({
  required String? beforeSessionRaw,
  required String? afterSessionRaw,
  String fieldName = 'sessionRaw',
}) {
  final sessionChanged = afterSessionRaw != beforeSessionRaw;
  expect(
    sessionChanged,
    isFalse,
    reason:
        'Expected $fieldName to remain unchanged (beforePresent: ${beforeSessionRaw != null}, afterPresent: ${afterSessionRaw != null})',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const ownerUserId = 'android-worker-test-owner';
  const replacementUserId = 'android-worker-replacement-user';
  const testDatabaseName = 'daftari_android_worker_test';
  const testStorageNamespace = 'daftari_android_worker_test';
  const testUniqueWorkName = 'com.mgb.daftari.cloud_backup.scheduled.test';

  // Isolated test storage: never touches the installed debug app's 'daftari'
  // SQLite database, default FlutterSecureStorage namespace, or default
  // WorkManager unique work queue (P12-17).
  const testSecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: testStorageNamespace,
      resetOnError: false,
    ),
  );
  const testSessionStorage = SecureSupabaseLocalStorage(testSecureStorage);

  // Read-only handles to the ordinary debug installation used strictly to
  // verify that pre-existing records, login and scheduled work ID survive
  // untouched without any writes from the test (P12-17).
  const productionSecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );
  const productionSessionStorage = SecureSupabaseLocalStorage(
    productionSecureStorage,
  );

  AppDatabase openIsolatedTestDatabase() =>
      AppDatabase(driftDatabase(name: testDatabaseName));

  File ordinaryDatabaseFile() =>
      File('${Directory.systemTemp.parent.path}/app_flutter/daftari.sqlite');

  Future<void> deleteIsolatedTestFiles() async {
    final appDataDir = Directory.systemTemp.parent.path;
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File(
        '$appDataDir/app_flutter/$testDatabaseName.sqlite$suffix',
      );
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    final lockFile = File('$appDataDir/files/daftari_cloud_backup_test.lock');
    if (lockFile.existsSync()) {
      try {
        await lockFile.delete();
      } catch (_) {}
    }
  }

  Future<
    ({
      bool databaseFileExisted,
      List<Customer> customers,
      List<TransactionRecord> transactions,
      List<TransactionAuditLog> auditLogs,
      BackupMetadataSnapshot metadata,
      BackupInFlightBatchRow? inFlightBatch,
      String? deviceId,
      String? ownerId,
      String? sessionRaw,
      List<Map<String, Object?>> activeProductionWork,
    })
  >
  snapshotOrdinaryInstallationReadOnly(
    AndroidBackupPlatformBridge bridge,
  ) async {
    final dbExisted = ordinaryDatabaseFile().existsSync();
    var customers = const <Customer>[];
    var transactions = const <TransactionRecord>[];
    var auditLogs = const <TransactionAuditLog>[];
    var metadata = const BackupMetadataSnapshot.initial();
    BackupInFlightBatchRow? inFlightBatch;
    String? deviceId;

    if (dbExisted) {
      final prodDb = AppDatabase();
      try {
        customers = await (prodDb.select(
          prodDb.customers,
        )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
        transactions = await (prodDb.select(
          prodDb.transactions,
        )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
        auditLogs = await (prodDb.select(
          prodDb.transactionAuditLogs,
        )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
        metadata = await prodDb.backupDao.readMetadata();
        inFlightBatch = await prodDb.backupDao.readInFlightBatch();
        deviceId = await prodDb.backupDao.readDeviceId();
      } finally {
        await prodDb.close();
      }
    }

    final ownerId = await productionSecureStorage.read(
      key: LedgerOwnerStorage.ownerKey,
    );
    final sessionRaw = await productionSessionStorage.accessToken();
    final prodWorkInfos = await bridge.getProductionUniqueWorkInfosForTest();
    final activeProductionWork = prodWorkInfos
        .where(
          (i) =>
              i['state'] != 'SUCCEEDED' &&
              i['state'] != 'FAILED' &&
              i['state'] != 'CANCELLED',
        )
        .toList(growable: false);
    return (
      databaseFileExisted: dbExisted,
      customers: customers,
      transactions: transactions,
      auditLogs: auditLogs,
      metadata: metadata,
      inFlightBatch: inFlightBatch,
      deviceId: deviceId,
      ownerId: ownerId,
      sessionRaw: sessionRaw,
      activeProductionWork: activeProductionWork,
    );
  }

  Future<DateTime> seedDueLedger(
    AppDatabase db, {
    required String customerName,
    BackupSchedule schedule = BackupSchedule.daily,
    DateTime? lastConfirmedAt,
    DateTime? nextDueAt,
    FlutterSecureStorage storage = testSecureStorage,
    SecureSupabaseLocalStorage sessionStorage = testSessionStorage,
    String ownerId = ownerUserId,
  }) async {
    final dueAt =
        nextDueAt?.toUtc() ??
        DateTime.now().toUtc().subtract(const Duration(minutes: 5));
    await db.customStatement('DELETE FROM backup_in_flight_batches');
    await db.customStatement('DELETE FROM transaction_audit_logs');
    await db.customStatement('DELETE FROM transactions');
    await db.customStatement('DELETE FROM customers');
    await db.customStatement('DELETE FROM backup_metadata');
    await db.customerDao.createCustomer(name: customerName);
    await db.backupDao.updateScheduleMetadata(
      (latest, _) => BackupMetadataSnapshot(
        schedule: schedule.name,
        lastConfirmedAtIso: lastConfirmedAt?.toUtc().toIso8601String(),
        nextDueAtIso: dueAt.toIso8601String(),
        isDeviceActive: true,
      ),
    );
    await storage.write(key: LedgerOwnerStorage.ownerKey, value: ownerId);
    await sessionStorage.persistSession(
      jsonEncode({
        'user': {
          'id': ownerId,
          'email': '$ownerId@example.com',
          'shop_name': 'Worker Test Shop',
        },
      }),
    );
    return dueAt;
  }

  Future<String?> waitForTerminalWorkState(
    AndroidBackupPlatformBridge bridge,
    String workId,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      final state = await bridge.getWorkStateForTest(workId);
      if (state == 'SUCCEEDED' || state == 'FAILED' || state == 'CANCELLED') {
        return state;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return bridge.getWorkStateForTest(workId);
  }

  testWidgets(
    'Android WorkManager isolates fixture storage and WorkManager queue, preserves running worker on app launch and interval switch with one successor, serializes commit ordering, and rejects replacement session acknowledgment',
    (tester) async {
      await tester.runAsync(() async {
        final bridge = AndroidBackupPlatformBridge();
        final prodBefore = await snapshotOrdinaryInstallationReadOnly(bridge);
        await bridge.configureTestEnvironment(
          databaseName: testDatabaseName,
          storageNamespace: testStorageNamespace,
          uniqueWorkName: testUniqueWorkName,
        );
        var db = openIsolatedTestDatabase();
        final fgGate = SessionCommitGate(coordinator: bridge);
        try {
          // 1. Replacing a schedule leaves one active job in the isolated
          // queue; syncing the same schedule again preserves the existing work
          // ID without churning.
          final now = DateTime.now().toUtc();
          final dailySchedule = BackupScheduleState(
            schedule: BackupSchedule.daily,
            nextDueAt: now.add(const Duration(days: 1)),
          );
          await bridge.syncSchedule(dailySchedule, now: now);
          final dailyInfos1 = await bridge.getUniqueWorkInfosForTest();
          final activeDaily1 = dailyInfos1
              .where(
                (i) =>
                    i['state'] != 'SUCCEEDED' &&
                    i['state'] != 'FAILED' &&
                    i['state'] != 'CANCELLED',
              )
              .toList();
          expect(activeDaily1.length, 1);

          // Same schedule target -> preserves existing work ID.
          await bridge.syncSchedule(
            dailySchedule,
            now: now.add(const Duration(minutes: 10)),
          );
          final dailyInfos2 = await bridge.getUniqueWorkInfosForTest();
          final activeDaily2 = dailyInfos2
              .where(
                (i) =>
                    i['state'] != 'SUCCEEDED' &&
                    i['state'] != 'FAILED' &&
                    i['state'] != 'CANCELLED',
              )
              .toList();
          expect(activeDaily2.length, 1);
          expect(activeDaily2.single['id'], activeDaily1.single['id']);

          // Different schedule target -> replaces with one active Monthly job.
          await bridge.syncSchedule(
            BackupScheduleState(
              schedule: BackupSchedule.monthly,
              nextDueAt: now.add(const Duration(days: 30)),
            ),
            now: now,
          );
          expect(await bridge.getScheduledWorkCount(), 1);
          await bridge.cancelScheduledBackup();
          await Future<void>.delayed(const Duration(milliseconds: 300));
          expect(await bridge.getScheduledWorkCount(), 0);

          // 2. P12-15 Part A: Run a due Android job, open the foreground app
          // during publication, and inspect both work IDs. Require one
          // publication, SUCCEEDED for the original ID, and one successor at
          // nextDueAt.
          final dueAt = await seedDueLedger(
            db,
            customerName: 'P12-15 Running Successor Customer',
          );
          await bridge.armTestCommitPause(
            BackupWorkerModes.testCommitPauseStageDuringPublication,
          );
          final workId15 = await bridge.enqueueImmediateWorkForTest(
            requireNetwork: false,
            workerMode: BackupWorkerModes.testPauseDuringPublication,
            schedule: BackupSchedule.daily.name,
            nextDueAtEpochMs: dueAt.millisecondsSinceEpoch,
          );
          expect(workId15, isNotNull);

          final reachedPublication = await bridge.waitForTestCommitPause(
            timeout: const Duration(seconds: 25),
          );
          expect(reachedPublication, isTrue);

          // Open/initialize the foreground app BackupCubit while worker is uploading.
          final fgDateService = SystemDateService();
          final fgAuthService = _TestForegroundAuthService(
            testSessionStorage,
            fgGate,
          );
          final fgPublisher = _CountingForegroundPublisher();

          // Foreground dependencies are always built from a live connection;
          // they are rebuilt whenever the isolated database is reopened (P12-21).
          BackupCubit buildForegroundCubit(AppDatabase liveDb) {
            final fgStore = DriftBackupLocalStore(
              backupDao: liveDb.backupDao,
              authService: fgAuthService,
              ownerStorage: LedgerOwnerStorage(testSecureStorage),
              deviceStorage: BackupDeviceStorage(
                testSecureStorage,
                liveDb.backupDao,
              ),
              connectivityService: ConnectivityService(Connectivity()),
              errorHandler: ErrorHandler(
                AppLogger(enableCrashReporting: false),
              ),
              commitGate: fgGate,
              isBackupRunning: () => bridge.isLocked,
              hasPersistedSession: testSessionStorage.hasAccessToken,
              readPersistedSession: testSessionStorage.readSessionSnapshot,
            );
            return BackupCubit(
              runBackup: RunBackupUseCase(
                localStore: fgStore,
                cloudPublisher: fgPublisher,
                runLock: bridge,
                dateService: fgDateService,
              ),
              updateSchedule: UpdateBackupScheduleUseCase(
                localStore: fgStore,
                dateService: fgDateService,
              ),
              localStore: fgStore,
              scheduler: bridge,
              runLock: bridge,
              dateService: fgDateService,
              readAuthState: () => const AuthSessionState(
                initialized: true,
                isConfigured: true,
                status: AuthStatus.authenticated,
                user: AuthUser(
                  id: ownerUserId,
                  email: 'worker-test@example.com',
                  shopName: 'Worker Test Shop',
                  emailVerified: true,
                ),
              ),
              authStateStream: const Stream.empty(),
              connectivityStream: const Stream.empty(),
              externalChangesStream: bridge.onExternalBackupStateChanged,
              checkRemoteRunLocked: bridge.refreshRemoteRunLocked,
            );
          }

          var fgCubit = buildForegroundCubit(db);

          Future<void> reopenDatabaseWithFreshForeground() async {
            await fgCubit.close();
            await db.close();
            db = openIsolatedTestDatabase();
            fgCubit = buildForegroundCubit(db);
          }

          await fgCubit.initialize();
          expect(fgCubit.state.status, BackupStatus.running);
          expect(fgPublisher.publishCalls, 0);
          expect(await bridge.getWorkStateForTest(workId15!), 'RUNNING');

          // Release publication and wait for worker completion.
          await bridge.releaseTestCommitPause();
          final terminal15 = await waitForTerminalWorkState(bridge, workId15);
          expect(terminal15, 'SUCCEEDED');
          expect(fgPublisher.publishCalls, 0);

          final meta15 = await db.backupDao.readMetadata();
          expect(meta15.lastConfirmedAtIso, isNotNull);
          expect(meta15.nextDueAtIso, isNotNull);
          final expectedNextDueMs = DateTime.parse(meta15.nextDueAtIso!)
              .toUtc()
              .millisecondsSinceEpoch;
          final expectedTargetTag =
              'com.mgb.daftari.cloud_backup.target:daily:$expectedNextDueMs';

          final workInfos15 = await bridge.getUniqueWorkInfosForTest();
          final originalInfo15 = workInfos15.firstWhere(
            (i) => i['id'] == workId15,
          );
          expect(originalInfo15['state'], 'SUCCEEDED');

          final unfinished15 = workInfos15
              .where(
                (i) =>
                    i['state'] != 'SUCCEEDED' &&
                    i['state'] != 'FAILED' &&
                    i['state'] != 'CANCELLED',
              )
              .toList();
          expect(unfinished15.length, 1);
          final successor15 = unfinished15.single;
          expect(successor15['id'], isNot(workId15));
          expect(successor15['state'], 'ENQUEUED');
          final successorTags = (successor15['tags'] as List<Object?>)
              .whereType<String>()
              .toList();
          expect(successorTags, contains(expectedTargetTag));
          final successorNextScheduleMs =
              (successor15['nextScheduleTimeMillis'] as num).toInt();
          expect(
            (successorNextScheduleMs - expectedNextDueMs).abs(),
            lessThan(30000),
          );

          await bridge.cancelScheduledBackup();
          await Future<void>.delayed(const Duration(milliseconds: 200));

          // 3. P12-15 Part B: Pause DURING publication (before acknowledgment)
          // with an overdue previous monthly confirmation, switch interval from
          // monthly to daily in the foreground, release the worker, reopen
          // SQLite, and compare the successor's actual scheduled instant and
          // target tag with reopened SQLite.
          final overdueLastConfirmed = DateTime.now().toUtc().subtract(
            const Duration(days: 40),
          );
          final overdueMonthlyDueAt = DateTime.now().toUtc().subtract(
            const Duration(days: 10),
          );
          await seedDueLedger(
            db,
            customerName: 'P12-15 During Publication Interval Switch Customer',
            schedule: BackupSchedule.monthly,
            lastConfirmedAt: overdueLastConfirmed,
            nextDueAt: overdueMonthlyDueAt,
          );
          await bridge.armTestCommitPause(
            BackupWorkerModes.testCommitPauseStageDuringPublication,
          );
          final workIdPubSwitch = await bridge.enqueueImmediateWorkForTest(
            requireNetwork: false,
            workerMode: BackupWorkerModes.testPauseDuringPublication,
            schedule: BackupSchedule.monthly.name,
            nextDueAtEpochMs: overdueMonthlyDueAt.millisecondsSinceEpoch,
          );
          expect(workIdPubSwitch, isNotNull);

          final reachedDuringPubSwitch = await bridge.waitForTestCommitPause(
            timeout: const Duration(seconds: 25),
          );
          expect(reachedDuringPubSwitch, isTrue);

          // Change monthly to daily while worker is paused DURING publication
          // (before acknowledgment), when the previous confirmation is overdue.
          await fgCubit.selectSchedule(BackupSchedule.daily);
          expect(
            (await db.backupDao.readMetadata()).schedule,
            BackupSchedule.daily.name,
            reason: 'Foreground write must persist while the worker is paused',
          );

          await bridge.releaseTestCommitPause();
          final terminalPubSwitch = await waitForTerminalWorkState(
            bridge,
            workIdPubSwitch!,
          );
          expect(terminalPubSwitch, 'SUCCEEDED');

          await reopenDatabaseWithFreshForeground();
          final metaPubSwitch = await db.backupDao.readMetadata();
          expect(metaPubSwitch.schedule, BackupSchedule.daily.name);
          expect(metaPubSwitch.lastConfirmedAtIso, isNotNull);
          expect(metaPubSwitch.nextDueAtIso, isNotNull);
          final confirmedPubSwitch = DateTime.parse(
            metaPubSwitch.lastConfirmedAtIso!,
          ).toUtc();
          expect(confirmedPubSwitch.isAfter(overdueLastConfirmed), isTrue);
          final expectedPubDailyDueMs = DateTime.parse(
            metaPubSwitch.nextDueAtIso!,
          ).toUtc().millisecondsSinceEpoch;
          final expectedPubDailyTag =
              'com.mgb.daftari.cloud_backup.target:daily:$expectedPubDailyDueMs';

          final infosPubSwitch = await bridge.getUniqueWorkInfosForTest();
          final unfinishedPubSwitch = infosPubSwitch
              .where(
                (i) =>
                    i['state'] != 'SUCCEEDED' &&
                    i['state'] != 'FAILED' &&
                    i['state'] != 'CANCELLED',
              )
              .toList();
          expect(unfinishedPubSwitch.length, 1);
          final successorPubSwitch = unfinishedPubSwitch.single;
          expect(successorPubSwitch['id'], isNot(workIdPubSwitch));
          expect(successorPubSwitch['state'], 'ENQUEUED');
          final pubSwitchTags = (successorPubSwitch['tags'] as List<Object?>)
              .whereType<String>()
              .toList();
          expect(pubSwitchTags, contains(expectedPubDailyTag));
          final pubSwitchScheduleMs =
              (successorPubSwitch['nextScheduleTimeMillis'] as num).toInt();
          expect(
            (pubSwitchScheduleMs - expectedPubDailyDueMs).abs(),
            lessThan(5000),
          );

          await bridge.cancelScheduledBackup();
          await Future<void>.delayed(const Duration(milliseconds: 200));

          // 3b. P12-15 Part C: Pause AFTER the worker reads its next due time
          // (monthly), switch interval from monthly to daily in the foreground,
          // release the worker, and verify one successor matching SQLite's
          // latest daily due time.
          final dueAtMonthly = await seedDueLedger(
            db,
            customerName: 'P12-15 Interval Switch Customer',
            schedule: BackupSchedule.monthly,
          );
          await bridge.armTestCommitPause(
            BackupWorkerModes.testCommitPauseStageAfterScheduleDecision,
          );
          final workIdSwitch = await bridge.enqueueImmediateWorkForTest(
            requireNetwork: false,
            workerMode: BackupWorkerModes.testPauseAfterScheduleDecision,
            schedule: BackupSchedule.monthly.name,
            nextDueAtEpochMs: dueAtMonthly.millisecondsSinceEpoch,
          );
          expect(workIdSwitch, isNotNull);

          final reachedAfterDecision = await bridge.waitForTestCommitPause(
            timeout: const Duration(seconds: 25),
          );
          expect(reachedAfterDecision, isTrue);

          // Switch interval from monthly to daily while worker is paused after
          // reading its monthly next due time.
          await fgCubit.selectSchedule(BackupSchedule.daily);
          expect(
            (await db.backupDao.readMetadata()).schedule,
            BackupSchedule.daily.name,
            reason: 'Foreground write must persist while the worker is paused',
          );

          await bridge.releaseTestCommitPause();
          final terminalSwitch = await waitForTerminalWorkState(
            bridge,
            workIdSwitch!,
          );
          expect(terminalSwitch, 'SUCCEEDED');

          final metaSwitch = await db.backupDao.readMetadata();
          expect(metaSwitch.schedule, BackupSchedule.daily.name);
          expect(metaSwitch.nextDueAtIso, isNotNull);
          final expectedDailyDueMs = DateTime.parse(metaSwitch.nextDueAtIso!)
              .toUtc()
              .millisecondsSinceEpoch;
          final expectedDailyTag =
              'com.mgb.daftari.cloud_backup.target:daily:$expectedDailyDueMs';

          final infosSwitch = await bridge.getUniqueWorkInfosForTest();
          final unfinishedSwitch = infosSwitch
              .where(
                (i) =>
                    i['state'] != 'SUCCEEDED' &&
                    i['state'] != 'FAILED' &&
                    i['state'] != 'CANCELLED',
              )
              .toList();
          expect(unfinishedSwitch.length, 1);
          final successorSwitch = unfinishedSwitch.single;
          expect(successorSwitch['id'], isNot(workIdSwitch));
          expect(successorSwitch['state'], 'ENQUEUED');
          final switchTags = (successorSwitch['tags'] as List<Object?>)
              .whereType<String>()
              .toList();
          expect(switchTags, contains(expectedDailyTag));
          final switchScheduleMs =
              (successorSwitch['nextScheduleTimeMillis'] as num).toInt();
          expect(
            (switchScheduleMs - expectedDailyDueMs).abs(),
            lessThan(30000),
          );

          await bridge.cancelScheduledBackup();
          await Future<void>.delayed(const Duration(milliseconds: 200));

          // 3c. P12-15 Part D: Pause immediately after the worker's FINAL
          // SQLite read and before its native enqueue, switch monthly to daily
          // through the foreground, wait for the foreground sync to return,
          // then release the worker. The successor must match reopened SQLite.
          final dueAtFinalRead = await seedDueLedger(
            db,
            customerName: 'P12-15 Final Read Race Customer',
            schedule: BackupSchedule.monthly,
          );
          await bridge.armTestCommitPause(
            BackupWorkerModes.testCommitPauseStageAfterFinalScheduleRead,
          );
          final workIdFinalRead = await bridge.enqueueImmediateWorkForTest(
            requireNetwork: false,
            workerMode: BackupWorkerModes.testPauseAfterFinalScheduleRead,
            schedule: BackupSchedule.monthly.name,
            nextDueAtEpochMs: dueAtFinalRead.millisecondsSinceEpoch,
          );
          expect(workIdFinalRead, isNotNull);
          expect(
            await bridge.waitForTestCommitPause(
              timeout: const Duration(seconds: 25),
            ),
            isTrue,
          );

          await fgCubit.selectSchedule(BackupSchedule.daily);
          expect(
            (await db.backupDao.readMetadata()).schedule,
            BackupSchedule.daily.name,
            reason: 'Foreground write must persist while the worker is paused',
          );

          await bridge.releaseTestCommitPause();
          final terminalFinalRead = await waitForTerminalWorkState(
            bridge,
            workIdFinalRead!,
          );
          expect(terminalFinalRead, 'SUCCEEDED');
          await reopenDatabaseWithFreshForeground();

          final metaFinalRead = await db.backupDao.readMetadata();
          expect(metaFinalRead.schedule, BackupSchedule.daily.name);
          expect(metaFinalRead.nextDueAtIso, isNotNull);
          final expectedFinalDueMs = DateTime.parse(metaFinalRead.nextDueAtIso!)
              .toUtc()
              .millisecondsSinceEpoch;
          final expectedFinalTag =
              'com.mgb.daftari.cloud_backup.target:daily:$expectedFinalDueMs';

          final infosFinalRead = await bridge.getUniqueWorkInfosForTest();
          final unfinishedFinalRead = infosFinalRead
              .where(
                (i) =>
                    i['state'] != 'SUCCEEDED' &&
                    i['state'] != 'FAILED' &&
                    i['state'] != 'CANCELLED',
              )
              .toList();
          expect(unfinishedFinalRead.length, 1);
          final successorFinalRead = unfinishedFinalRead.single;
          expect(successorFinalRead['id'], isNot(workIdFinalRead));
          expect(successorFinalRead['state'], 'ENQUEUED');
          expect(
            (successorFinalRead['tags'] as List<Object?>).whereType<String>(),
            contains(expectedFinalTag),
          );
          expect(
            ((successorFinalRead['nextScheduleTimeMillis'] as num).toInt() -
                    expectedFinalDueMs)
                .abs(),
            lessThan(30000),
          );
          await fgCubit.close();

          await bridge.cancelScheduledBackup();
          await Future<void>.delayed(const Duration(milliseconds: 200));

          // 4. P12-11 Case A: Pause the ACTUAL Android BackupWorker isolate AT
          // SQLite COMMIT, initiate foreground sign-out, verify sign-out waits
          // until COMMIT finishes, then reopen SQLite and verify acknowledged
          // revisions & cleared in-flight batch persist.
          await seedDueLedger(db, customerName: 'Commit Race Customer');
          await bridge.armTestCommitPause(
            BackupWorkerModes.testCommitPauseStageDuringCommit,
          );

          final workIdA = await bridge.enqueueImmediateWorkForTest(
            requireNetwork: false,
            workerMode: BackupWorkerModes.testPauseDuringSqliteCommit,
          );
          expect(workIdA, isNotNull);

          final reachedCommit = await bridge.waitForTestCommitPause(
            timeout: const Duration(seconds: 25),
          );
          expect(reachedCommit, isTrue);

          var signOutCompleted = false;
          final signOutFuture = fgGate.runSessionInvalidation(() async {
            await testSessionStorage.removePersistedSession();
            signOutCompleted = true;
          });

          // Foreground sign-out MUST wait while worker holds commit gate.
          await Future<void>.delayed(const Duration(milliseconds: 300));
          expect(signOutCompleted, isFalse);
          expect(await testSessionStorage.hasAccessToken(), isTrue);

          // Release worker SQLite COMMIT and verify safe ordering.
          await bridge.releaseTestCommitPause();
          await signOutFuture;
          expect(signOutCompleted, isTrue);
          expect(await testSessionStorage.hasAccessToken(), isFalse);

          final terminalA = await waitForTerminalWorkState(bridge, workIdA!);
          expect(terminalA, 'SUCCEEDED');

          await db.close();
          db = openIsolatedTestDatabase();
          expect(await db.backupDao.countPendingChanges(), 0);
          expect(await db.backupDao.readInFlightBatch(), isNull);
          final metaA = await db.backupDao.readMetadata();
          expect(metaA.lastConfirmedAtIso, isNotNull);

          // 5. P12-11 Case B: Pause the ACTUAL Android BackupWorker isolate
          // BEFORE commit gate, complete foreground sign-out, release worker,
          // reopen SQLite and verify SQLite rolled back cleanly with pending
          // data preserved.
          await seedDueLedger(db, customerName: 'Rollback Race Customer');
          await bridge.armTestCommitPause(
            BackupWorkerModes.testCommitPauseStageBeforeGate,
          );

          final workIdB = await bridge.enqueueImmediateWorkForTest(
            requireNetwork: false,
            workerMode: BackupWorkerModes.testPauseBeforeCommitGate,
          );
          expect(workIdB, isNotNull);

          final reachedBeforeGate = await bridge.waitForTestCommitPause(
            timeout: const Duration(seconds: 25),
          );
          expect(reachedBeforeGate, isTrue);

          await fgGate.runSessionInvalidation(() async {
            await testSessionStorage.removePersistedSession();
          });
          expect(await testSessionStorage.hasAccessToken(), isFalse);

          await bridge.releaseTestCommitPause();
          final terminalB = await waitForTerminalWorkState(bridge, workIdB!);
          expect(terminalB, 'SUCCEEDED');

          await db.close();
          db = openIsolatedTestDatabase();
          expect(await db.backupDao.countPendingChanges(), 1);
          expect(await db.backupDao.readInFlightBatch(), isNotNull);
          final metaB = await db.backupDao.readMetadata();
          expect(metaB.lastConfirmedAtIso, isNull);

          // 6. P12-16: Pause after server publication, complete foreground
          // sign-out and a different account sign-in, then release the worker.
          // Reopen SQLite and assert the confirmed time and acknowledged
          // revisions did not advance.
          await seedDueLedger(
            db,
            customerName: 'P12-16 Replacement Session Customer',
          );
          await bridge.armTestCommitPause(
            BackupWorkerModes.testCommitPauseStageAfterPublication,
          );

          final workId16 = await bridge.enqueueImmediateWorkForTest(
            requireNetwork: false,
            workerMode: BackupWorkerModes.testPauseAfterPublication,
          );
          expect(workId16, isNotNull);

          final reachedAfterPub = await bridge.waitForTestCommitPause(
            timeout: const Duration(seconds: 25),
          );
          expect(reachedAfterPub, isTrue);

          // Complete foreground sign-out of ownerUserId AND sign-in of replacementUserId.
          await fgGate.runSessionInvalidation(() async {
            await testSessionStorage.removePersistedSession();
          });
          await testSessionStorage.persistSession(
            jsonEncode({
              'user': {
                'id': replacementUserId,
                'email': 'replacement-user@example.com',
                'shop_name': 'Replacement Shop',
              },
            }),
          );
          expect(await testSessionStorage.hasAccessToken(), isTrue);

          await bridge.releaseTestCommitPause();
          final terminal16 = await waitForTerminalWorkState(bridge, workId16!);
          expect(terminal16, 'SUCCEEDED');

          await db.close();
          db = openIsolatedTestDatabase();
          expect(await db.backupDao.countPendingChanges(), 1);
          expect(await db.backupDao.readInFlightBatch(), isNotNull);
          final customers16 = await db.select(db.customers).get();
          expect(customers16.single.acknowledgedRevision, 0);
          final meta16 = await db.backupDao.readMetadata();
          expect(meta16.lastConfirmedAtIso, isNull);

          // 6b. Phase 13: Queued old-device Android BackupWorker isolate runs
          // after authority transferred to another phone (isDeviceActive=false).
          // Verify the worker skips publication, retains pending offline edits,
          // cannot reacquire authority, and does not enqueue a successor.
          await bridge.cancelScheduledBackup();
          await seedDueLedger(
            db,
            customerName: 'P13 Inactive Old Device Worker Customer',
          );
          await db.backupDao.markDeviceInactive();
          final workIdInactive = await bridge.enqueueImmediateWorkForTest(
            requireNetwork: false,
            workerMode: BackupWorkerModes.production,
          );
          expect(workIdInactive, isNotNull);
          final terminalInactive = await waitForTerminalWorkState(
            bridge,
            workIdInactive!,
          );
          expect(terminalInactive, 'SUCCEEDED');

          await db.close();
          db = openIsolatedTestDatabase();
          expect(await db.backupDao.countPendingChanges(), 1);
          final metaInactive = await db.backupDao.readMetadata();
          expect(metaInactive.isDeviceActive, isFalse);
          expect(metaInactive.lastConfirmedAtIso, isNull);
          expect(await bridge.getScheduledWorkCount(), 0);

          // 6c. Phase 13 (P13-05): Verify through WorkManager with a due batch
          // on the receiving phone while the PendingRestoreTransfer marker is
          // persisted in RestoreTransferStorage. Keep the marker present
          // through the worker result, verify zero publisher calls and
          // unchanged pending rows, then complete installation and check that
          // a new edit can publish via WorkManager.
          const testTransferStorage = RestoreTransferStorage(testSecureStorage);
          await seedDueLedger(
            db,
            customerName: 'P13 Pre-Restore Pending Customer On B',
          );
          final targetDeviceStorage = BackupDeviceStorage(
            testSecureStorage,
            db.backupDao,
          );
          final targetDeviceId = await targetDeviceStorage
              .getOrCreateDeviceId();
          final restoreLocalStore = DriftRestoreLocalStore(
            backupDao: db.backupDao,
            authService: fgAuthService,
            ownerStorage: LedgerOwnerStorage(testSecureStorage),
            deviceStorage: targetDeviceStorage,
            errorHandler: ErrorHandler(AppLogger(enableCrashReporting: false)),
            commitGate: fgGate,
            hasPersistedSession: testSessionStorage.hasAccessToken,
            readPersistedSession: testSessionStorage.readSessionSnapshot,
          );
          final preRestoreSummary =
              (await restoreLocalStore.readLocalLedgerSummary()).getOrElse(
                (_) => throw StateError('failed'),
              );
          final restoredTimestamp = DateTime.utc(2026, 11, 25, 10);
          final blockedPreview = CloudBackupSnapshotPreview(
            version: 'v1',
            ownerUserId: ownerUserId,
            activeDeviceId: targetDeviceId,
            confirmedAt: restoredTimestamp,
            customerCount: 1,
          );
          final stagedSnapshot = CloudBackupSnapshot(
            preview: blockedPreview,
            customers: [
              BackupCustomerRecord(
                id: 'p13-restored-cloud-customer-1',
                name: 'P13 Restored Cloud Customer',
                phone: null,
                notes: null,
                createdAt: restoredTimestamp,
                updatedAt: restoredTimestamp,
                deletedAt: null,
                localRevision: 1,
              ),
            ],
            transactions: const [],
            auditLogs: const [],
          );
          await testTransferStorage.writePendingTransfer(
            transfer: PendingRestoreTransfer(
              requestId: 'p13-worker-block-req',
              ownerUserId: ownerUserId,
              targetDeviceId: targetDeviceId,
              expectedVersion: 'v1',
              expectedActiveDeviceId: 'device-old',
              confirmedAt: restoredTimestamp,
              requiresTakeover: true,
              requiresReplacement: true,
              consentedLocalRevisionStamp: preRestoreSummary.revisionStamp,
              stage: RestoreTransferStage.takeoverConfirmed,
              cloudPreview: blockedPreview,
            ),
            stagedSnapshot: stagedSnapshot,
          );

          // Enqueue the receiving phone's WorkManager BackupWorker while the
          // pending restore marker exists and wait for the worker run to finish.
          final workerFinishedSignal = bridge.onExternalBackupStateChanged.first
              .timeout(const Duration(seconds: 25));
          final workIdBlocked = await bridge.enqueueImmediateWorkForTest(
            requireNetwork: false,
            workerMode: BackupWorkerModes.production,
          );
          expect(workIdBlocked, isNotNull);
          await workerFinishedSignal;

          // Wait for WorkManager to transition out of RUNNING after completeWorker.
          final settledDeadline = DateTime.now().add(
            const Duration(seconds: 10),
          );
          while (DateTime.now().isBefore(settledDeadline)) {
            final state = await bridge.getWorkStateForTest(workIdBlocked!);
            if (state != 'RUNNING') break;
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }

          // Marker is still present after the worker result; reopen SQLite and
          // verify zero publisher calls (no in-flight capture, no confirmedAt)
          // and unchanged pending rows.
          expect(await testTransferStorage.hasPendingTransfer(), isTrue);
          await db.close();
          db = openIsolatedTestDatabase();
          expect(await db.backupDao.countPendingChanges(), 1);
          expect(await db.backupDao.readInFlightBatch(), isNull);
          final metaBlocked = await db.backupDao.readMetadata();
          expect(metaBlocked.lastConfirmedAtIso, isNull);
          expect(
            (await db.select(db.customers).get()).single.name,
            'P13 Pre-Restore Pending Customer On B',
          );

          await bridge.cancelScheduledBackup();

          // Complete local installation on B and clear the pending transfer marker.
          final restoreStoreAfterReopen = DriftRestoreLocalStore(
            backupDao: db.backupDao,
            authService: fgAuthService,
            ownerStorage: LedgerOwnerStorage(testSecureStorage),
            deviceStorage: BackupDeviceStorage(testSecureStorage, db.backupDao),
            errorHandler: ErrorHandler(AppLogger(enableCrashReporting: false)),
            commitGate: fgGate,
            hasPersistedSession: testSessionStorage.hasAccessToken,
            readPersistedSession: testSessionStorage.readSessionSnapshot,
          );
          final installResult =
              (await restoreStoreAfterReopen.installConfirmedSnapshot(
                snapshot: stagedSnapshot,
                consent: RestoreConsentToken(
                  version: 'v1',
                  activeDeviceId: targetDeviceId,
                  confirmedAt: restoredTimestamp,
                  ownerUserId: ownerUserId,
                  localDeviceId: targetDeviceId,
                  localRevisionStamp: preRestoreSummary.revisionStamp,
                  requiresTakeover: true,
                  requiresReplacement: true,
                  primaryConfirmed: true,
                  replacementConfirmed: true,
                ),
              )).getOrElse((_) => throw StateError('install failed'));
          expect(installResult, isA<RestoreLocalInstallApplied>());
          await testTransferStorage.clearPendingTransfer();
          expect(await testTransferStorage.hasPendingTransfer(), isFalse);
          expect(await db.backupDao.countPendingChanges(), 0);

          // Make a new edit on B, mark schedule due, and verify it publishes
          // via WorkManager now that installation is complete.
          await db.customerDao.createCustomer(
            name: 'P13 Post-Restore New Edit Customer On B',
          );
          final postRestoreDueAt = DateTime.now().toUtc().subtract(
            const Duration(minutes: 5),
          );
          await db.backupDao.updateScheduleMetadata(
            (latest, _) => BackupMetadataSnapshot(
              schedule: BackupSchedule.daily.name,
              lastConfirmedAtIso: latest.lastConfirmedAtIso,
              nextDueAtIso: postRestoreDueAt.toIso8601String(),
              isDeviceActive: true,
            ),
          );
          expect(await db.backupDao.countPendingChanges(), 1);

          final workIdPostRestore = await bridge.enqueueImmediateWorkForTest(
            requireNetwork: false,
            workerMode: BackupWorkerModes.production,
            schedule: BackupSchedule.daily.name,
            nextDueAtEpochMs: postRestoreDueAt.millisecondsSinceEpoch,
          );
          expect(workIdPostRestore, isNotNull);
          final terminalPostRestore = await waitForTerminalWorkState(
            bridge,
            workIdPostRestore!,
          );
          expect(terminalPostRestore, 'SUCCEEDED');

          await db.close();
          db = openIsolatedTestDatabase();
          expect(await db.backupDao.countPendingChanges(), 0);
          final postRestoreCustomers = await db.select(db.customers).get();
          expect(postRestoreCustomers.length, 2);
          expect(
            postRestoreCustomers.every((c) => c.acknowledgedRevision == 1),
            isTrue,
          );
          await bridge.cancelScheduledBackup();
        } finally {
          await const RestoreTransferStorage(testSecureStorage)
              .clearPendingTransfer();
          await bridge.cancelScheduledBackup();
          await bridge.clearTestHooks();
          await testSessionStorage.removePersistedSession();
          await testSecureStorage.delete(key: LedgerOwnerStorage.ownerKey);
          await db.close();
          await deleteIsolatedTestFiles();
        }

        // 7. P12-20 Verification: Force a mismatch with synthetic session
        // strings and verify that the failure names the changed field and
        // contains neither synthetic token.
        const syntheticTokenA = 'synthetic-secret-token-alpha-9001';
        const syntheticTokenB = 'synthetic-secret-token-beta-9002';
        TestFailure? forcedMismatchFailure;
        try {
          expectOrdinarySessionUnchanged(
            beforeSessionRaw: '{"access_token":"$syntheticTokenA"}',
            afterSessionRaw: '{"access_token":"$syntheticTokenB"}',
          );
        } on TestFailure catch (failure) {
          forcedMismatchFailure = failure;
        }
        expect(forcedMismatchFailure, isNotNull);
        final failureText = forcedMismatchFailure.toString();
        expect(failureText, contains('sessionRaw'));
        expect(failureText, isNot(contains(syntheticTokenA)));
        expect(failureText, isNot(contains(syntheticTokenB)));

        // 8. P12-17 Read-Only Verification: Confirm the ordinary installation
        // retained its exact database existence/records, login and scheduled
        // work ID untouched.
        final prodAfter = await snapshotOrdinaryInstallationReadOnly(bridge);

        debugPrint(
          'P12-17 read-only snapshot before=(dbExisted:${prodBefore.databaseFileExisted}, '
          'customers:${prodBefore.customers.length}, '
          'txs:${prodBefore.transactions.length}, '
          'hasOwner:${prodBefore.ownerId != null}, '
          'hasSession:${prodBefore.sessionRaw != null}, '
          'workIds:${prodBefore.activeProductionWork.map((w) => w['id']).toList()}) '
          'after=(dbExisted:${prodAfter.databaseFileExisted}, '
          'customers:${prodAfter.customers.length}, '
          'txs:${prodAfter.transactions.length}, '
          'hasOwner:${prodAfter.ownerId != null}, '
          'hasSession:${prodAfter.sessionRaw != null}, '
          'workIds:${prodAfter.activeProductionWork.map((w) => w['id']).toList()})',
        );

        expect(prodAfter.databaseFileExisted, prodBefore.databaseFileExisted);
        expect(prodAfter.customers, prodBefore.customers);
        expect(prodAfter.transactions, prodBefore.transactions);
        expect(prodAfter.auditLogs, prodBefore.auditLogs);
        expect(prodAfter.metadata, prodBefore.metadata);
        expect(prodAfter.inFlightBatch, prodBefore.inFlightBatch);
        expect(prodAfter.deviceId, prodBefore.deviceId);
        expect(prodAfter.ownerId, prodBefore.ownerId);
        expectOrdinarySessionUnchanged(
          beforeSessionRaw: prodBefore.sessionRaw,
          afterSessionRaw: prodAfter.sessionRaw,
        );
        expect(
          prodAfter.activeProductionWork.map((w) => w['id']).toList(),
          prodBefore.activeProductionWork.map((w) => w['id']).toList(),
        );

        // 9. P12-17 Overlapping Ordinary + Fixture Verification on a
        // disposable empty installation: run an ordinary due request (with no
        // fixture keys) overlapping an active paused fixture request, and
        // verify both ledgers and both successor queues independently.
        final isDisposableEmptyInstall =
            !prodBefore.databaseFileExisted &&
            prodBefore.ownerId == null &&
            prodBefore.sessionRaw == null &&
            prodBefore.activeProductionWork.isEmpty;

        if (isDisposableEmptyInstall) {
          final ordinaryBridge = AndroidBackupPlatformBridge();
          await bridge.configureTestEnvironment(
            databaseName: testDatabaseName,
            storageNamespace: testStorageNamespace,
            uniqueWorkName: testUniqueWorkName,
          );
          var fixtureDb = openIsolatedTestDatabase();
          var ordinaryDb = AppDatabase();
          try {
            final fixtureDueAt = await seedDueLedger(
              fixtureDb,
              customerName: 'Overlapping Fixture Customer',
              schedule: BackupSchedule.daily,
            );
            final ordinaryDueAt = await seedDueLedger(
              ordinaryDb,
              customerName: 'Overlapping Ordinary Customer',
              schedule: BackupSchedule.weekly,
              storage: productionSecureStorage,
              sessionStorage: productionSessionStorage,
              ownerId: 'ordinary-overlap-owner',
            );

            // Start the fixture worker and hold it in publication while the
            // ordinary due request starts and completes concurrently.
            await bridge.armTestCommitPause(
              BackupWorkerModes.testCommitPauseStageDuringPublication,
            );
            final fixtureWorkId = await bridge.enqueueImmediateWorkForTest(
              requireNetwork: false,
              workerMode: BackupWorkerModes.testPauseDuringPublication,
              schedule: BackupSchedule.daily.name,
              nextDueAtEpochMs: fixtureDueAt.millisecondsSinceEpoch,
            );
            expect(fixtureWorkId, isNotNull);
            expect(
              await bridge.waitForTestCommitPause(
                timeout: const Duration(seconds: 25),
              ),
              isTrue,
            );

            // Enqueue the ordinary due worker with NO fixture keys while the
            // fixture environment and fixture worker are actively running.
            final ordinaryWorkId = await ordinaryBridge
                .enqueueImmediateWorkForTest(
                  requireNetwork: false,
                  workerMode: BackupWorkerModes.testPauseDuringPublication,
                  schedule: BackupSchedule.weekly.name,
                  nextDueAtEpochMs: ordinaryDueAt.millisecondsSinceEpoch,
                );
            expect(ordinaryWorkId, isNotNull);

            final ordinaryTerminal = await waitForTerminalWorkState(
              ordinaryBridge,
              ordinaryWorkId!,
            );
            expect(ordinaryTerminal, 'SUCCEEDED');

            // Fixture worker must still be RUNNING until released.
            expect(await bridge.getWorkStateForTest(fixtureWorkId!), 'RUNNING');
            await bridge.releaseTestCommitPause();
            final fixtureTerminal = await waitForTerminalWorkState(
              bridge,
              fixtureWorkId,
            );
            expect(fixtureTerminal, 'SUCCEEDED');

            await ordinaryDb.close();
            await fixtureDb.close();
            ordinaryDb = AppDatabase();
            fixtureDb = openIsolatedTestDatabase();

            // Check ordinary ledger and ordinary successor queue.
            expect(await ordinaryDb.backupDao.countPendingChanges(), 0);
            final ordinaryCustomers = await ordinaryDb
                .select(ordinaryDb.customers)
                .get();
            expect(
              ordinaryCustomers.single.name,
              'Overlapping Ordinary Customer',
            );
            expect(ordinaryCustomers.single.acknowledgedRevision, 1);
            final ordinaryMeta = await ordinaryDb.backupDao.readMetadata();
            expect(ordinaryMeta.schedule, BackupSchedule.weekly.name);
            expect(ordinaryMeta.lastConfirmedAtIso, isNotNull);
            expect(ordinaryMeta.nextDueAtIso, isNotNull);
            final ordinaryExpectedDueMs = DateTime.parse(
              ordinaryMeta.nextDueAtIso!,
            ).toUtc().millisecondsSinceEpoch;
            final ordinaryExpectedTag =
                'com.mgb.daftari.cloud_backup.target:weekly:$ordinaryExpectedDueMs';

            final ordinaryInfos = await ordinaryBridge
                .getProductionUniqueWorkInfosForTest();
            final ordinaryUnfinished = ordinaryInfos
                .where(
                  (i) =>
                      i['state'] != 'SUCCEEDED' &&
                      i['state'] != 'FAILED' &&
                      i['state'] != 'CANCELLED',
                )
                .toList();
            expect(ordinaryUnfinished.length, 1);
            expect(ordinaryUnfinished.single['id'], isNot(ordinaryWorkId));
            expect(ordinaryUnfinished.single['state'], 'ENQUEUED');
            expect(
              (ordinaryUnfinished.single['tags'] as List<Object?>)
                  .whereType<String>(),
              contains(ordinaryExpectedTag),
            );

            // Check fixture ledger and fixture successor queue.
            expect(await fixtureDb.backupDao.countPendingChanges(), 0);
            final fixtureCustomers = await fixtureDb
                .select(fixtureDb.customers)
                .get();
            expect(
              fixtureCustomers.single.name,
              'Overlapping Fixture Customer',
            );
            expect(fixtureCustomers.single.acknowledgedRevision, 1);
            final fixtureMeta = await fixtureDb.backupDao.readMetadata();
            expect(fixtureMeta.schedule, BackupSchedule.daily.name);
            expect(fixtureMeta.lastConfirmedAtIso, isNotNull);
            expect(fixtureMeta.nextDueAtIso, isNotNull);
            final fixtureExpectedDueMs = DateTime.parse(
              fixtureMeta.nextDueAtIso!,
            ).toUtc().millisecondsSinceEpoch;
            final fixtureExpectedTag =
                'com.mgb.daftari.cloud_backup.target:daily:$fixtureExpectedDueMs';

            final fixtureInfos = await bridge.getUniqueWorkInfosForTest();
            final fixtureUnfinished = fixtureInfos
                .where(
                  (i) =>
                      i['state'] != 'SUCCEEDED' &&
                      i['state'] != 'FAILED' &&
                      i['state'] != 'CANCELLED',
                )
                .toList();
            expect(fixtureUnfinished.length, 1);
            expect(fixtureUnfinished.single['id'], isNot(fixtureWorkId));
            expect(fixtureUnfinished.single['state'], 'ENQUEUED');
            expect(
              (fixtureUnfinished.single['tags'] as List<Object?>)
                  .whereType<String>(),
              contains(fixtureExpectedTag),
            );
          } finally {
            await ordinaryBridge.cancelScheduledBackup();
            await bridge.cancelScheduledBackup();
            await bridge.clearTestHooks();
            await productionSessionStorage.removePersistedSession();
            await productionSecureStorage.delete(
              key: LedgerOwnerStorage.ownerKey,
            );
            await testSessionStorage.removePersistedSession();
            await testSecureStorage.delete(key: LedgerOwnerStorage.ownerKey);
            await ordinaryDb.close();
            await fixtureDb.close();
            await deleteIsolatedTestFiles();
            final appDataDir = Directory.systemTemp.parent.path;
            for (final suffix in ['', '-wal', '-shm']) {
              final f = File('$appDataDir/app_flutter/daftari.sqlite$suffix');
              if (f.existsSync()) {
                try {
                  await f.delete();
                } catch (_) {}
              }
            }
            await ordinaryBridge.dispose();
          }
        }

        await bridge.dispose();
      });
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
