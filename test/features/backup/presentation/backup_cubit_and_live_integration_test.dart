import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/connectivity_service.dart';
import 'package:daftariapp/core/services/session_commit_gate.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/utils/app_date_utils.dart';
import 'package:daftariapp/features/auth/session/data/services/ledger_owner_storage.dart';
import 'package:daftariapp/features/auth/session/data/services/supabase_auth_service.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_state.dart';
import 'package:daftariapp/features/backup/data/repositories/drift_backup_local_store.dart';
import 'package:daftariapp/features/backup/data/services/backup_device_storage.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_batch.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_eligibility.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_run_result.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_schedule.dart';
import 'package:daftariapp/features/backup/domain/repositories/backup_cloud_publisher.dart';
import 'package:daftariapp/features/backup/domain/repositories/backup_scheduler.dart';
import 'package:daftariapp/features/backup/domain/usecases/run_backup_usecase.dart';
import 'package:daftariapp/features/backup/domain/usecases/update_backup_schedule_usecase.dart';
import 'package:daftariapp/features/backup/presentation/cubit/backup_cubit.dart';
import 'package:daftariapp/features/backup/presentation/models/backup_view_state.dart';
import 'package:daftariapp/features/backup/presentation/screens/backup_screen.dart';
import 'package:daftariapp/features/backup/presentation/widgets/backup_settings_section.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../domain/backup_domain_fakes.dart';

class _MockConnectivity extends Mock implements Connectivity {}

class _RecordingScheduler implements BackupScheduler {
  final List<(BackupScheduleState, DateTime)> syncCalls = [];
  int cancelCalls = 0;

  @override
  Future<void> syncSchedule(
    BackupScheduleState scheduleState, {
    required DateTime now,
  }) async {
    if (!scheduleState.hasSchedule) {
      cancelCalls++;
      return;
    }
    syncCalls.add((scheduleState, now.toUtc()));
  }

  @override
  Future<void> cancelScheduledBackup() async {
    cancelCalls++;
  }
}

class _SharedCrossIsolateCoordinator implements SessionCommitCoordinator {
  int _epoch = 0;
  int _pendingInvalidations = 0;
  int _activeCommits = 0;
  final List<Completer<void>> _waiters = [];

  @override
  Future<int> readEpoch() async => _epoch;

  @override
  Future<bool> tryEnterCommit({required int expectedEpoch}) async {
    if (_pendingInvalidations > 0 || _epoch != expectedEpoch) {
      return false;
    }
    _activeCommits++;
    return true;
  }

  @override
  Future<void> exitCommit() async {
    if (_activeCommits > 0) _activeCommits--;
    if (_activeCommits == 0) {
      final waiters = List<Completer<void>>.of(_waiters);
      _waiters.clear();
      for (final waiter in waiters) {
        if (!waiter.isCompleted) waiter.complete();
      }
    }
  }

  @override
  Future<void> beginSessionInvalidation() async {
    _pendingInvalidations++;
    while (_activeCommits > 0) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
  }

  @override
  Future<void> endSessionInvalidation() async {
    _epoch++;
    if (_pendingInvalidations > 0) _pendingInvalidations--;
  }
}

class _LiveFakeAuthService implements AuthService {
  _LiveFakeAuthService({this.user, this.commitGate, this.persistedSessionFlag});

  final StreamController<AuthSessionEvent> _controller =
      StreamController<AuthSessionEvent>.broadcast();
  final SessionCommitGate? commitGate;
  final ValueNotifier<bool>? persistedSessionFlag;

  AuthUser? user;

  @override
  bool get isConfigured => true;

  @override
  AuthUser? get currentUser => user;

  @override
  Future<AuthUser?> getCurrentUser() async => user;

  @override
  Stream<AuthSessionEvent> watchAuthChanges() => _controller.stream;

  @override
  Future<void> signOut({String? expectedUserId}) {
    Future<void> perform() async {
      user = null;
      persistedSessionFlag?.value = false;
      _controller.add(const AuthSessionSignedOut());
    }

    final gate = commitGate;
    return gate == null ? perform() : gate.runSessionInvalidation(perform);
  }

  void signIn(AuthUser next) {
    user = next;
    persistedSessionFlag?.value = true;
    _controller.add(AuthSessionSignedIn(next));
  }

  Future<void> dispose() => _controller.close();

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

class _DelayCommitInterceptor extends QueryInterceptor {
  _DelayCommitInterceptor({required this.onCommitAcknowledgment});

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
    final pause = _sawInFlightDelete;
    _sawInFlightDelete = false;
    if (pause) {
      await onCommitAcknowledgment();
    }
    await inner.send();
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    _sawInFlightDelete = false;
    await inner.rollback();
  }
}

class _LiveFakeCloudPublisher implements BackupCloudPublisher {
  final List<BackupBatch> publishedBatches = [];
  final Map<String, DateTime> confirmedTimes = {};
  DateTime serverTime = DateTime.utc(2026, 11, 24, 12);
  AppFailure? nextFailure;
  Future<void> Function(BackupBatch batch)? beforePublish;

  @override
  Future<Either<AppFailure, BackupPublicationResult?>> findBatchConfirmation({
    required String batchId,
    required String ownerUserId,
    required String deviceId,
  }) async {
    final existing = confirmedTimes[batchId];
    if (existing == null) return const Right(null);
    return Right(
      BackupPublicationConfirmed(batchId: batchId, confirmedAt: existing),
    );
  }

  @override
  Future<Either<AppFailure, BackupPublicationResult>> publishBatch(
    BackupBatch batch,
  ) async {
    if (beforePublish case final hook?) {
      await hook(batch);
    }
    if (nextFailure case final failure?) {
      nextFailure = null;
      return Left(failure);
    }
    publishedBatches.add(batch);
    final confirmedAt = confirmedTimes.putIfAbsent(
      batch.batchId,
      () => serverTime.toUtc(),
    );
    return Right(
      BackupPublicationConfirmed(
        batchId: batch.batchId,
        confirmedAt: confirmedAt,
      ),
    );
  }
}

const _ownerUser = AuthUser(
  id: 'user-owner',
  email: 'merchant@example.com',
  shopName: 'Al-Amana Grocery',
  emailVerified: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await AppDateUtils.initialize();
  });

  late Directory tempDir;
  late File dbFile;
  late FlutterSecureStorage secureStorage;
  late FakeDateService dateService;
  late _RecordingScheduler scheduler;
  late InMemoryBackupRunLock runLock;
  late _LiveFakeCloudPublisher cloudPublisher;
  late StreamController<List<ConnectivityResult>> connectivityController;
  late _MockConnectivity connectivity;
  late ValueNotifier<bool> persistedSession;
  late _SharedCrossIsolateCoordinator crossCoordinator;
  late StreamController<AuthSessionState> authStateController;
  late AuthSessionState currentAuthState;
  late StreamController<void> externalChanges;

  ErrorHandler createErrorHandler() =>
      ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('daftari_backup_t4_');
    dbFile = File('${tempDir.path}${Platform.pathSeparator}daftari.sqlite');
    FlutterSecureStorage.setMockInitialValues({
      LedgerOwnerStorage.ownerKey: _ownerUser.id,
    });
    secureStorage = const FlutterSecureStorage();
    dateService = FakeDateService(DateTime.utc(2026, 11, 24, 10));
    scheduler = _RecordingScheduler();
    runLock = InMemoryBackupRunLock();
    cloudPublisher = _LiveFakeCloudPublisher()
      ..serverTime = DateTime.utc(2026, 11, 24, 10, 5);
    connectivityController =
        StreamController<List<ConnectivityResult>>.broadcast();
    connectivity = _MockConnectivity();
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => connectivityController.stream);
    persistedSession = ValueNotifier<bool>(true);
    crossCoordinator = _SharedCrossIsolateCoordinator();
    authStateController = StreamController<AuthSessionState>.broadcast();
    currentAuthState = const AuthSessionState(
      initialized: true,
      isConfigured: true,
      status: AuthStatus.authenticated,
      user: _ownerUser,
    );
    externalChanges = StreamController<void>.broadcast();
  });

  tearDown(() async {
    await connectivityController.close();
    await authStateController.close();
    await externalChanges.close();
    persistedSession.dispose();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  ({
    AppDatabase db,
    _LiveFakeAuthService authService,
    DriftBackupLocalStore localStore,
    RunBackupUseCase runBackup,
    UpdateBackupScheduleUseCase updateSchedule,
    BackupCubit cubit,
    Future<void> Function() dispose,
  })
  openAppInstance({
    QueryInterceptor? interceptor,
    Future<void> Function()? beforeEnterCommitHook,
    bool autoTearDown = true,
  }) {
    final baseExecutor = NativeDatabase(dbFile);
    final db = AppDatabase(
      interceptor == null
          ? baseExecutor
          : baseExecutor.interceptWith(interceptor),
    );
    final commitGate = SessionCommitGate(coordinator: crossCoordinator);
    final authService = _LiveFakeAuthService(
      user: persistedSession.value ? _ownerUser : null,
      commitGate: commitGate,
      persistedSessionFlag: persistedSession,
    );
    final deviceStorage = BackupDeviceStorage(secureStorage, db.backupDao);
    final ownerStorage = LedgerOwnerStorage(secureStorage);
    final connectivityService = ConnectivityService(connectivity);
    final errorHandler = createErrorHandler();
    final localStore = DriftBackupLocalStore(
      backupDao: db.backupDao,
      authService: authService,
      ownerStorage: ownerStorage,
      deviceStorage: deviceStorage,
      connectivityService: connectivityService,
      errorHandler: errorHandler,
      commitGate: commitGate,
      isBackupRunning: () => runLock.isLocked,
      hasPersistedSession: () async => persistedSession.value,
      beforeEnterCommitHook: beforeEnterCommitHook,
    );
    final runBackup = RunBackupUseCase(
      localStore: localStore,
      cloudPublisher: cloudPublisher,
      runLock: runLock,
      dateService: dateService,
    );
    final updateSchedule = UpdateBackupScheduleUseCase(
      localStore: localStore,
      dateService: dateService,
    );
    final localChanges = StreamController<void>.broadcast();
    final sub1 = db.backupDao.watchMetadata().listen(
      (_) => localChanges.add(null),
      onError: (_) {},
    );
    final sub2 = db.backupDao.watchPendingChangesCount().listen(
      (_) => localChanges.add(null),
      onError: (_) {},
    );
    final cubit = BackupCubit(
      runBackup: runBackup,
      updateSchedule: updateSchedule,
      localStore: localStore,
      scheduler: scheduler,
      runLock: runLock,
      dateService: dateService,
      readAuthState: () => currentAuthState,
      authStateStream: authStateController.stream,
      connectivityStream: connectivityService.onConnectivityChanged,
      localChangesStream: localChanges.stream,
      externalChangesStream: externalChanges.stream,
    );
    var disposed = false;
    Future<void> dispose() async {
      if (disposed) return;
      disposed = true;
      await sub1.cancel();
      await sub2.cancel();
      await localChanges.close();
      await cubit.close();
      await authService.dispose();
      await db.close();
    }

    if (autoTearDown) {
      addTearDown(dispose);
    }
    return (
      db: db,
      authService: authService,
      localStore: localStore,
      runBackup: runBackup,
      updateSchedule: updateSchedule,
      cubit: cubit,
      dispose: dispose,
    );
  }

  Future<void> pumpBackupWidget(
    WidgetTester tester,
    Widget child, {
    required BackupCubit backupCubit,
    AuthSessionCubit? authCubit,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = <BlocProvider>[
      BlocProvider<BackupCubit>.value(value: backupCubit),
      if (authCubit != null)
        BlocProvider<AuthSessionCubit>.value(value: authCubit),
    ];
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: providers,
        child: ScreenUtilInit(
          designSize: AppConstants.designSize,
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, _) => MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppConstants.supportedLocales,
            theme: AppTheme.light,
            home: child,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder backupNowButton() => find.descendant(
    of: find.byKey(const ValueKey('backup-now')),
    matching: find.byType(FilledButton),
  );

  testWidgets(
    'Settings and Manage Backup wire live state, schedule replacement, manual backup, and edit-during-upload',
    (tester) async {
      final app = (await tester.runAsync(() async {
        final instance = openAppInstance(autoTearDown: false);
        await instance.cubit.initialize();
        return instance;
      }))!;
      try {
        // Empty ledger: no preview banner, Back up now disabled, 0 uploads.
        await pumpBackupWidget(
          tester,
          const Scaffold(
            body: SingleChildScrollView(child: BackupSettingsSection()),
          ),
          backupCubit: app.cubit,
        );
        expect(
          find.byKey(const ValueKey('backup-preview-banner')),
          findsNothing,
        );
        expect(
          tester.widget<FilledButton>(backupNowButton()).onPressed,
          isNull,
        );
        expect(cloudPublisher.publishedBatches, isEmpty);

        // Add a customer and a transaction worth 100 EGP (10000 piasters).
        late String txId;
        late DateTime txDate;
        late String customerId;
        await tester.runAsync(() async {
          final customer = await app.db.customerDao.createCustomer(
            name: 'Hassan',
          );
          customerId = customer.id;
          final tx = await app.db.transactionDao.createTransaction(
            customerId: customer.id,
            type: TransactionTypes.credit,
            amountPiasters: 10000,
          );
          txId = tx.id;
          txDate = tx.transactionDate;
          await app.cubit.refresh();
        });
        await tester.pump();

        expect(app.cubit.state.pendingChanges, 2);
        expect(app.cubit.state.canBackUpNow, isTrue);
        expect(
          tester.widget<FilledButton>(backupNowButton()).onPressed,
          isNotNull,
        );

        // Pause during upload to edit tx 100 -> 150 and add another transaction.
        final uploadStarted = Completer<void>();
        final releaseUpload = Completer<void>();
        cloudPublisher.beforePublish = (batch) async {
          if (!uploadStarted.isCompleted) uploadStarted.complete();
          await releaseUpload.future;
        };

        await tester.tap(find.byKey(const ValueKey('backup-now')));
        await tester.pump();
        await tester.runAsync(() => uploadStarted.future);
        await tester.pump();

        // While running: status is running and Back up now is disabled.
        expect(app.cubit.state.status, BackupStatus.running);
        expect(
          tester.widget<FilledButton>(backupNowButton()).onPressed,
          isNull,
        );

        await tester.runAsync(() async {
          await app.db.transactionDao.editTransaction(
            id: txId,
            type: TransactionTypes.credit,
            amountPiasters: 15000,
            transactionDate: txDate,
          );
          await app.db.transactionDao.createTransaction(
            customerId: customerId,
            type: TransactionTypes.payment,
            amountPiasters: 2500,
          );
          cloudPublisher.beforePublish = null;
        });
        releaseUpload.complete();
        for (var i = 0; i < 20 && app.cubit.state.isRunning; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        await tester.runAsync(() => app.cubit.refresh());
        await tester.pump();

        // First confirmed batch captured 10000; edit + new tx + audit stay pending.
        expect(cloudPublisher.publishedBatches.length, 1);
        expect(
          cloudPublisher
              .publishedBatches
              .first
              .transactions
              .single
              .amountPiasters,
          10000,
        );
        expect(
          app.cubit.state.lastConfirmedAt,
          DateTime.utc(2026, 11, 24, 10, 5),
        );
        expect(app.cubit.state.pendingChanges, 3);
        expect(app.cubit.state.status, BackupStatus.pending);

        // Second manual backup captures the edit (15000), new tx, and audit once.
        cloudPublisher.serverTime = DateTime.utc(2026, 11, 24, 10, 15);
        await tester.runAsync(() => app.cubit.backUpNow());
        await tester.pump();

        expect(cloudPublisher.publishedBatches.length, 2);
        expect(app.cubit.state.pendingChanges, 0);
        expect(app.cubit.state.status, BackupStatus.upToDate);
        expect(app.cubit.state.canBackUpNow, isFalse);

        // Switch to Manage Backup screen and select Weekly, then replace with Monthly.
        await pumpBackupWidget(
          tester,
          const BackupScreen(),
          backupCubit: app.cubit,
        );
        await tester.tap(find.byKey(const ValueKey('backup-schedule-weekly')));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        expect(app.cubit.state.schedule, BackupSchedule.weekly);

        await tester.tap(find.byKey(const ValueKey('backup-schedule-monthly')));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        expect(app.cubit.state.schedule, BackupSchedule.monthly);
        expect(
          app.cubit.state.lastConfirmedAt,
          DateTime.utc(2026, 11, 24, 10, 15),
        );
        expect(scheduler.syncCalls.last.$1.schedule, BackupSchedule.monthly);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(app.dispose);
      }
    },
  );

  test('app restart retries overdue daily/weekly/monthly schedule and advances unchanged overdue ledger without looping', () async {
    // Process 1: confirm initial backup on Jan 31 and pick Monthly schedule.
    dateService.current = DateTime.utc(2026, 1, 31, 9);
    cloudPublisher.serverTime = DateTime.utc(2026, 1, 31, 9);
    final p1 = openAppInstance();
    await p1.cubit.initialize();
    await p1.db.customerDao.createCustomer(name: 'Mona');
    await p1.cubit.selectSchedule(BackupSchedule.monthly);
    await p1.cubit.backUpNow();
    expect(p1.cubit.state.lastConfirmedAt, DateTime.utc(2026, 1, 31, 9));
    // Add a new local change for the next monthly backup.
    await p1.db.customerDao.createCustomer(name: 'Tarek');
    await p1.cubit.close();
    await p1.db.close();

    // Process 2 (simulated cold app restart on Feb 28 — clamped month end!):
    dateService.current = DateTime.utc(2026, 2, 28, 9);
    cloudPublisher.serverTime = DateTime.utc(2026, 2, 28, 9, 1);
    final p2 = openAppInstance();
    await p2.cubit.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(cloudPublisher.publishedBatches.length, 2);
    expect(p2.cubit.state.lastConfirmedAt, DateTime.utc(2026, 2, 28, 9, 1));
    expect(p2.cubit.state.pendingChanges, 0);
    await p2.cubit.close();
    await p2.db.close();

    // Process 3 (overdue on Mar 30 with ZERO pending changes): advances nextDueAt
    // without uploading and without looping!
    dateService.current = DateTime.utc(2026, 3, 30, 10);
    final p3 = openAppInstance();
    await p3.cubit.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(cloudPublisher.publishedBatches.length, 2);
    final saved = (await p3.localStore.readScheduleState()).getOrElse(
      (_) => throw StateError('failed'),
    );
    expect(saved.nextDueAt, DateTime.utc(2026, 4, 30, 10));
    expect(saved.lastConfirmedAt, DateTime.utc(2026, 2, 28, 9, 1));
  });

  test('deferred connectivity waits offline and runs overdue backup automatically when connectivity returns', () async {
    // Start online to create data and set Daily schedule.
    final app = openAppInstance();
    await app.cubit.initialize();
    await app.db.customerDao.createCustomer(name: 'Nadia');
    await app.cubit.selectSchedule(BackupSchedule.daily);

    // Go offline and advance clock past due date (+1 day).
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);
    dateService.current = DateTime.utc(2026, 11, 25, 11);
    connectivityController.add([ConnectivityResult.none]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(app.cubit.state.canBackUpNow, isFalse);
    expect(cloudPublisher.publishedBatches, isEmpty);

    // Restore connectivity -> overdue backup runs automatically.
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
    cloudPublisher.serverTime = DateTime.utc(2026, 11, 25, 11, 2);
    connectivityController.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(cloudPublisher.publishedBatches.length, 1);
    expect(app.cubit.state.status, BackupStatus.upToDate);
    expect(app.cubit.state.lastConfirmedAt, DateTime.utc(2026, 11, 25, 11, 2));
  });

  test(
    'manual request overlapping scheduled work produces zero duplicate uploads',
    () async {
      final app = openAppInstance();
      await app.cubit.initialize();
      await app.db.customerDao.createCustomer(name: 'Omar');
      await app.cubit.selectSchedule(BackupSchedule.daily);

      dateService.current = DateTime.utc(2026, 11, 25, 12);
      final uploadStarted = Completer<void>();
      final releaseUpload = Completer<void>();
      cloudPublisher.beforePublish = (_) async {
        if (!uploadStarted.isCompleted) uploadStarted.complete();
        await releaseUpload.future;
      };

      // Start scheduled backup (simulating Android worker holding shared lock).
      final scheduledFuture = app.runBackup(trigger: BackupTrigger.scheduled);
      await uploadStarted.future;
      externalChanges.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Foreground sees running state and cannot start a duplicate manual run.
      expect(app.cubit.state.status, BackupStatus.running);
      expect(app.cubit.state.canBackUpNow, isFalse);
      await app.cubit.backUpNow();

      releaseUpload.complete();
      final scheduledResult = await scheduledFuture;
      expect(scheduledResult.isRight(), isTrue);
      expect(cloudPublisher.publishedBatches.length, 1);
    },
  );

  test('sign-out during upload preserves pending changes, prior confirmation, and owner binding', () async {
    final app = openAppInstance();
    await app.cubit.initialize();
    await app.db.customerDao.createCustomer(name: 'Youssef');

    final uploadStarted = Completer<void>();
    final releaseUpload = Completer<void>();
    cloudPublisher.beforePublish = (_) async {
      if (!uploadStarted.isCompleted) uploadStarted.complete();
      await releaseUpload.future;
    };

    final manualFuture = app.cubit.backUpNow();
    await uploadStarted.future;

    // Sign out while upload is in flight.
    await app.authService.signOut();
    currentAuthState = const AuthSessionState(
      initialized: true,
      isConfigured: true,
      status: AuthStatus.unauthenticated,
    );
    authStateController.add(currentAuthState);

    releaseUpload.complete();
    await manualFuture;

    expect(app.cubit.state.lastConfirmedAt, isNull);
    expect(app.cubit.state.pendingChanges, 1);
    expect(app.cubit.state.accountEmail, isNull);
    expect(app.cubit.state.canBackUpNow, isFalse);
    expect(
      await LedgerOwnerStorage(secureStorage).readOwnerId(),
      _ownerUser.id,
    );
  });

  test('cross-isolate P12-11: delaying worker SQLite COMMIT orders foreground sign-out strictly after commit', () async {
    final commitReached = Completer<void>();
    final releaseCommit = Completer<void>();

    // Foreground runtime initializes SQLite & seeds pending data before
    // the separate worker runtime opens its own connection to the same file.
    final foreground = openAppInstance();
    await foreground.db.customerDao.createCustomer(name: 'Samy');
    await foreground.updateSchedule(BackupSchedule.daily);
    dateService.current = DateTime.utc(2026, 11, 25, 12);
    cloudPublisher.serverTime = DateTime.utc(2026, 11, 25, 12, 5);

    final worker = openAppInstance(
      interceptor: _DelayCommitInterceptor(
        onCommitAcknowledgment: () async {
          if (!commitReached.isCompleted) commitReached.complete();
          await releaseCommit.future;
        },
      ),
    );

    final workerFuture = worker.runBackup(trigger: BackupTrigger.scheduled);
    await commitReached.future;

    // Foreground initiates sign-out while worker is inside SQLite COMMIT.
    var signOutCompleted = false;
    final signOutFuture = foreground.authService.signOut().then((_) {
      signOutCompleted = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(signOutCompleted, isFalse);
    expect(persistedSession.value, isTrue);

    // Release worker COMMIT: worker commits first, then foreground sign-out finishes.
    releaseCommit.complete();
    final workerResult = await workerFuture;
    await signOutFuture;

    expect(
      workerResult.getOrElse((_) => throw StateError('failed')),
      isA<BackupRunConfirmed>(),
    );
    expect(signOutCompleted, isTrue);
    expect(persistedSession.value, isFalse);
    expect(await foreground.db.backupDao.countPendingChanges(), 0);
    expect(await foreground.db.backupDao.readInFlightBatch(), isNull);
    final schedule = (await foreground.localStore.readScheduleState())
        .getOrElse((_) => throw StateError('failed'));
    expect(schedule.lastConfirmedAt, DateTime.utc(2026, 11, 25, 12, 5));
  });

  test('cross-isolate P12-11: foreground sign-out before worker commit gate rolls back worker SQLite writes', () async {
    final beforeGateReached = Completer<void>();
    final releaseBeforeGate = Completer<void>();

    final foreground = openAppInstance();
    await foreground.db.customerDao.createCustomer(name: 'Salma');
    await foreground.updateSchedule(BackupSchedule.daily);
    dateService.current = DateTime.utc(2026, 11, 25, 12);

    final worker = openAppInstance(
      beforeEnterCommitHook: () async {
        if (!beforeGateReached.isCompleted) beforeGateReached.complete();
        await releaseBeforeGate.future;
      },
    );

    final workerFuture = worker.runBackup(trigger: BackupTrigger.scheduled);
    await beforeGateReached.future;

    // Foreground signs out BEFORE worker enters commit gate.
    await foreground.authService.signOut();
    expect(persistedSession.value, isFalse);

    releaseBeforeGate.complete();
    final workerResult = await workerFuture;

    expect(
      workerResult.getOrElse((_) => throw StateError('failed')),
      isA<BackupRunSkipped>().having(
        (r) => r.reason,
        'reason',
        BackupIneligibilityReason.signedOut,
      ),
    );
    expect(await foreground.db.backupDao.countPendingChanges(), 1);
    expect(await foreground.db.backupDao.readInFlightBatch(), isNotNull);
    final schedule = (await foreground.localStore.readScheduleState())
        .getOrElse((_) => throw StateError('failed'));
    expect(schedule.lastConfirmedAt, isNull);
  });

  test('failed attempts preserve lastConfirmedAt and surface failed status accurately', () async {
    final app = openAppInstance();
    await app.cubit.initialize();
    await app.db.customerDao.createCustomer(name: 'Nour');

    // First attempt fails -> status failed, lastConfirmedAt stays null.
    cloudPublisher.nextFailure = const AppFailure(AppErrorCode.network);
    await app.cubit.backUpNow();
    expect(app.cubit.state.status, BackupStatus.failed);
    expect(app.cubit.state.lastConfirmedAt, isNull);

    // Retry succeeds -> confirmed timestamp recorded.
    cloudPublisher.serverTime = DateTime.utc(2026, 11, 24, 14);
    await app.cubit.backUpNow();
    expect(app.cubit.state.status, BackupStatus.upToDate);
    expect(app.cubit.state.lastConfirmedAt, DateTime.utc(2026, 11, 24, 14));

    // Later attempt fails -> status failed, previous lastConfirmedAt preserved!
    await app.db.customerDao.createCustomer(name: 'Hany');
    cloudPublisher.nextFailure = const AppFailure(AppErrorCode.network);
    await app.cubit.backUpNow();
    expect(app.cubit.state.status, BackupStatus.failed);
    expect(app.cubit.state.lastConfirmedAt, DateTime.utc(2026, 11, 24, 14));
  });

  test('cross-isolate P12-16: foreground sign-out and replacement sign-in during worker publication prevents stale worker acknowledgment', () async {
    final foreground = openAppInstance();
    final customer = await foreground.db.customerDao.createCustomer(
      name: 'Khaled',
    );
    await foreground.updateSchedule(BackupSchedule.daily);
    dateService.current = DateTime.utc(2026, 11, 25, 12);

    final worker = openAppInstance();
    final publishPaused = Completer<void>();
    final releasePublish = Completer<void>();
    cloudPublisher.beforePublish = (_) async {
      if (!publishPaused.isCompleted) publishPaused.complete();
      await releasePublish.future;
    };

    final workerFuture = worker.runBackup(trigger: BackupTrigger.scheduled);
    await publishPaused.future;
    cloudPublisher.beforePublish = null;

    // Foreground signs out AND signs in a replacement account while worker's
    // own AuthService still has _ownerUser cached in memory.
    await foreground.authService.signOut();
    foreground.authService.signIn(
      const AuthUser(
        id: 'user-replacement',
        email: 'replacement@example.com',
        shopName: 'Other Shop',
        emailVerified: true,
      ),
    );
    expect(persistedSession.value, isTrue);
    expect(worker.authService.currentUser?.id, _ownerUser.id);

    releasePublish.complete();
    final workerResult = await workerFuture;

    expect(
      workerResult.getOrElse((_) => throw StateError('failed')),
      isA<BackupRunSkipped>().having(
        (r) => r.reason,
        'reason',
        BackupIneligibilityReason.signedOut,
      ),
    );

    await worker.dispose();
    await foreground.dispose();

    final reopened = openAppInstance();
    expect(await reopened.db.backupDao.countPendingChanges(), 1);
    final reopenedCustomer = await reopened.db.customerDao.getCustomerById(
      customer.id,
    );
    expect(reopenedCustomer!.acknowledgedRevision, 0);
    expect(await reopened.db.backupDao.readInFlightBatch(), isNotNull);
    final schedule = (await reopened.localStore.readScheduleState()).getOrElse(
      (_) => throw StateError('failed'),
    );
    expect(schedule.lastConfirmedAt, isNull);
  });
}
