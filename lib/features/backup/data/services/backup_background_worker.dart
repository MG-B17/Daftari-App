import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/date_service.dart';
import '../../../../core/services/session_commit_gate.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../auth/session/data/services/ledger_owner_storage.dart';
import '../../../auth/session/data/services/secure_gotrue_storage.dart';
import '../../../auth/session/data/services/supabase_auth_service.dart';
import '../../../auth/session/data/services/supabase_bootstrap.dart';
import '../../../auth/session/domain/entities/auth_session_event.dart';
import '../../../auth/session/domain/entities/auth_user.dart';
import '../../domain/entities/backup_batch.dart';
import '../../domain/entities/backup_run_result.dart';
import '../../domain/entities/backup_schedule.dart';
import '../../domain/repositories/backup_cloud_publisher.dart';
import '../../domain/repositories/backup_scheduler.dart';
import '../../domain/usecases/run_backup_usecase.dart';
import '../repositories/drift_backup_local_store.dart';
import '../repositories/supabase_backup_cloud_publisher.dart';
import 'android_backup_platform_bridge.dart';
import 'backup_device_storage.dart';

/// Worker execution modes. Any non-production mode is ignored outside
/// [kDebugMode].
abstract final class BackupWorkerModes {
  static const production = 'production';
  static const testPauseDuringPublication = 'test_pause_during_publication';
  static const testPauseAfterPublication = 'test_pause_after_publication';
  static const testPauseAfterScheduleDecision =
      'test_pause_after_schedule_decision';
  static const testPauseAfterFinalScheduleRead =
      'test_pause_after_final_schedule_read';
  static const testPauseDuringSqliteCommit = 'test_pause_during_sqlite_commit';
  static const testPauseBeforeCommitGate = 'test_pause_before_commit_gate';
  static const testCommitPauseStageDuringPublication = 'during_publication';
  static const testCommitPauseStageAfterPublication = 'after_publication';
  static const testCommitPauseStageAfterScheduleDecision =
      'after_schedule_decision';
  static const testCommitPauseStageAfterFinalScheduleRead =
      'after_final_schedule_read';
  static const testCommitPauseStageDuringCommit = 'during_sqlite_commit';
  static const testCommitPauseStageBeforeGate = 'before_commit_gate';
}

/// Native VM entrypoint resolved directly from this library URI by Android's
/// `BackupWorker` in both production APK and `integration_test` bundles.
@pragma('vm:entry-point')
Future<void> backupWorkerMain(List<String> args) =>
    runBackupBackgroundWorker(args);

/// Entrypoint invoked by Android's `BackupWorker` inside a headless
/// `FlutterEngine` isolate.
///
/// Shares the exact same [RunBackupUseCase], [DriftBackupLocalStore],
/// [SupabaseBackupCloudPublisher], [BackupDeviceStorage], and cross-isolate
/// [AndroidBackupPlatformBridge] coordination used by the foreground app.
Future<void> runBackupBackgroundWorker(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDateUtils.initialize();

  final workerToken = args.isNotEmpty && args.first.trim().isNotEmpty
      ? args.first.trim()
      : 'worker-unknown';
  final requestedMode = args.length > 1 ? args[1].trim() : '';
  final customDatabaseName = kDebugMode && args.length > 2
      ? args[2].trim()
      : '';
  final customStorageNamespace = kDebugMode && args.length > 3
      ? args[3].trim()
      : '';
  final customUniqueWorkName = kDebugMode && args.length > 4
      ? args[4].trim()
      : '';
  final isDebugTestMode =
      kDebugMode &&
      (requestedMode == BackupWorkerModes.testPauseDuringPublication ||
          requestedMode == BackupWorkerModes.testPauseAfterPublication ||
          requestedMode == BackupWorkerModes.testPauseAfterScheduleDecision ||
          requestedMode == BackupWorkerModes.testPauseAfterFinalScheduleRead ||
          requestedMode == BackupWorkerModes.testPauseDuringSqliteCommit ||
          requestedMode == BackupWorkerModes.testPauseBeforeCommitGate ||
          customDatabaseName.isNotEmpty ||
          customStorageNamespace.isNotEmpty ||
          customUniqueWorkName.isNotEmpty);

  final platformBridge = AndroidBackupPlatformBridge(
    databaseName: customDatabaseName.isNotEmpty ? customDatabaseName : null,
    storageNamespace: customStorageNamespace.isNotEmpty
        ? customStorageNamespace
        : null,
    uniqueWorkName: customUniqueWorkName.isNotEmpty
        ? customUniqueWorkName
        : null,
  );
  var outcome = BackupWorkerOutcome.retry;
  AppDatabase? database;
  SupabaseBootstrap? bootstrap;

  try {
    final effectiveDbName = customDatabaseName.isNotEmpty
        ? customDatabaseName
        : 'daftari';
    final secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        resetOnError: false,
        storageNamespace: customStorageNamespace.isNotEmpty
            ? customStorageNamespace
            : null,
      ),
    );
    final commitGate = SessionCommitGate(coordinator: platformBridge);
    final dateService = SystemDateService();
    final logger = AppLogger(enableCrashReporting: false);
    final errorHandler = ErrorHandler(logger);

    final baseExecutor = driftDatabase(name: effectiveDbName);
    database =
        isDebugTestMode &&
            requestedMode == BackupWorkerModes.testPauseDuringSqliteCommit
        ? AppDatabase(
            baseExecutor.interceptWith(
              _DebugCommitPauseInterceptor(
                onCommitAcknowledgment: () =>
                    platformBridge.awaitTestCommitRelease(
                      BackupWorkerModes.testCommitPauseStageDuringCommit,
                    ),
              ),
            ),
          )
        : AppDatabase(baseExecutor);

    final persistedSessionStorage = SecureSupabaseLocalStorage(secureStorage);
    final deviceStorage = BackupDeviceStorage(
      secureStorage,
      database.backupDao,
    );
    final AuthService authService;
    BackupCloudPublisher cloudPublisher;

    final useRealSupabase = await _shouldUseRealSupabase(
      isDebugTestMode: isDebugTestMode,
      persistedSessionStorage: persistedSessionStorage,
    );

    if (!useRealSupabase) {
      authService = _DebugPersistedSessionAuthService(persistedSessionStorage);
      cloudPublisher = _DebugDeterministicCloudPublisher(dateService);
    } else {
      bootstrap = SupabaseBootstrap();
      await bootstrap.initialize(secureStorage);
      authService = SupabaseAuthService(bootstrap, commitGate: commitGate);
      cloudPublisher = SupabaseBackupCloudPublisher(
        bootstrap: bootstrap,
        authService: authService,
        deviceStorage: deviceStorage,
        errorHandler: errorHandler,
      );
    }

    if (isDebugTestMode &&
        (requestedMode == BackupWorkerModes.testPauseDuringPublication ||
            requestedMode == BackupWorkerModes.testPauseAfterPublication)) {
      cloudPublisher = _DebugPausingCloudPublisher(
        inner: cloudPublisher,
        onDuringPublish:
            requestedMode == BackupWorkerModes.testPauseDuringPublication
            ? () => platformBridge.awaitTestCommitRelease(
                BackupWorkerModes.testCommitPauseStageDuringPublication,
              )
            : null,
        onAfterPublish:
            requestedMode == BackupWorkerModes.testPauseAfterPublication
            ? () => platformBridge.awaitTestCommitRelease(
                BackupWorkerModes.testCommitPauseStageAfterPublication,
              )
            : null,
      );
    }

    final ownerStorage = LedgerOwnerStorage(secureStorage);
    final connectivityService = ConnectivityService(Connectivity());

    final localStore = DriftBackupLocalStore(
      backupDao: database.backupDao,
      authService: authService,
      ownerStorage: ownerStorage,
      deviceStorage: deviceStorage,
      connectivityService: connectivityService,
      errorHandler: errorHandler,
      commitGate: commitGate,
      isBackupRunning: () => platformBridge.isLocked,
      hasPersistedSession: persistedSessionStorage.hasAccessToken,
      readPersistedSession: persistedSessionStorage.readSessionSnapshot,
      beforeEnterCommitHook:
          isDebugTestMode &&
              requestedMode == BackupWorkerModes.testPauseBeforeCommitGate
          ? () => platformBridge.awaitTestCommitRelease(
              BackupWorkerModes.testCommitPauseStageBeforeGate,
            )
          : null,
    );

    final runBackup = RunBackupUseCase(
      localStore: localStore,
      cloudPublisher: cloudPublisher,
      runLock: platformBridge,
      dateService: dateService,
    );

    final runResult = await runBackup(trigger: BackupTrigger.scheduled);
    final decision = BackupWorkerPolicy.decide(runResult);
    outcome = decision.outcome;

    if (isDebugTestMode &&
        requestedMode == BackupWorkerModes.testPauseAfterScheduleDecision) {
      await platformBridge.awaitTestCommitRelease(
        BackupWorkerModes.testCommitPauseStageAfterScheduleDecision,
      );
    }

    if (decision.shouldCancelSchedule || decision.scheduleToSync != null) {
      await reconcileBackupWorkerSuccessor(
        readScheduleState: localStore.readScheduleState,
        syncSchedule: (schedule, now) => platformBridge.syncScheduleFromWorker(
          schedule,
          now: now,
          token: workerToken,
        ),
        cancelSchedule: () =>
            platformBridge.cancelScheduledBackupFromWorker(token: workerToken),
        now: dateService.now,
        onPauseAfterFinalRead:
            isDebugTestMode &&
                requestedMode ==
                    BackupWorkerModes.testPauseAfterFinalScheduleRead
            ? () => platformBridge.awaitTestCommitRelease(
                BackupWorkerModes.testCommitPauseStageAfterFinalScheduleRead,
              )
            : null,
      );
    }

    await platformBridge.notifyBackupStateChanged();
  } catch (_) {
    outcome = BackupWorkerOutcome.retry;
  } finally {
    try {
      await database?.close();
    } catch (_) {
      // Best-effort database close on worker exit.
    }
    try {
      await bootstrap?.client?.dispose();
    } catch (_) {
      // Best-effort Supabase client disposal.
    }
    await platformBridge.completeWorker(token: workerToken, outcome: outcome);
    await platformBridge.dispose();
  }
}

/// Enqueues the worker's single successor from the latest committed SQLite
/// schedule, retrying transient schedule read failures, then re-reads SQLite
/// after the native enqueue and re-enqueues if a foreground interval change
/// committed in between.
///
/// A foreground change persists SQLite before it calls native scheduling. When
/// that native call lands while this worker is still running with no queued
/// successor it is a no-op, so the post-enqueue re-read is what closes the
/// window between this worker's final read and its native enqueue.
@visibleForTesting
Future<void> reconcileBackupWorkerSuccessor({
  required Future<Either<AppFailure, BackupScheduleState>> Function()
  readScheduleState,
  required Future<void> Function(BackupScheduleState schedule, DateTime now)
  syncSchedule,
  required Future<void> Function() cancelSchedule,
  required DateTime Function() now,
  Future<void> Function()? onPauseAfterFinalRead,
  Duration retryDelay = const Duration(milliseconds: 50),
}) async {
  const maxReconcileRounds = 5;
  BackupScheduleState? lastEnqueued;
  var pausedOnce = false;
  for (var round = 0; round < maxReconcileRounds; round++) {
    final latest = await _readScheduleWithRetries(
      readScheduleState: readScheduleState,
      retryDelay: retryDelay,
    );
    if (lastEnqueued != null && latest == lastEnqueued) return;

    if (onPauseAfterFinalRead != null && !pausedOnce) {
      pausedOnce = true;
      await onPauseAfterFinalRead();
    }

    if (latest.hasSchedule) {
      await syncSchedule(latest, now());
    } else {
      await cancelSchedule();
    }
    lastEnqueued = latest;
  }

  final finalCheck = await _readScheduleWithRetries(
    readScheduleState: readScheduleState,
    retryDelay: retryDelay,
  );
  if (finalCheck == lastEnqueued) return;

  throw StateError(
    'Persisted backup schedule did not converge after '
    '$maxReconcileRounds reconciliation rounds',
  );
}

Future<BackupScheduleState> _readScheduleWithRetries({
  required Future<Either<AppFailure, BackupScheduleState>> Function()
  readScheduleState,
  required Duration retryDelay,
}) async {
  const maxReadAttempts = 5;
  AppFailure? lastFailure;
  for (var attempt = 0; attempt < maxReadAttempts; attempt++) {
    final readResult = await readScheduleState();
    final latest = readResult.fold<BackupScheduleState?>((failure) {
      lastFailure = failure;
      return null;
    }, (value) => value);
    if (latest != null) return latest;
    if (attempt + 1 < maxReadAttempts && retryDelay > Duration.zero) {
      await Future<void>.delayed(retryDelay);
    }
  }
  throw StateError(
    'Failed to read persisted backup schedule during successor '
    'reconciliation: ${lastFailure?.message ?? 'unknown error'}',
  );
}

Future<bool> _shouldUseRealSupabase({
  required bool isDebugTestMode,
  required SecureSupabaseLocalStorage persistedSessionStorage,
}) async {
  if (!isDebugTestMode) return true;
  if (!SupabaseBootstrap().hasValidConfig) return false;
  try {
    final raw = await persistedSessionStorage.accessToken();
    if (raw == null || raw.trim().isEmpty) return false;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return false;
    final accessToken = decoded['access_token'];
    final refreshToken = decoded['refresh_token'];
    return accessToken is String &&
        accessToken.trim().isNotEmpty &&
        refreshToken is String &&
        refreshToken.trim().isNotEmpty;
  } catch (_) {
    return false;
  }
}

class _DebugPausingCloudPublisher implements BackupCloudPublisher {
  _DebugPausingCloudPublisher({
    required this.inner,
    this.onDuringPublish,
    this.onAfterPublish,
  });

  final BackupCloudPublisher inner;
  final Future<void> Function()? onDuringPublish;
  final Future<void> Function()? onAfterPublish;

  @override
  Future<Either<AppFailure, BackupPublicationResult?>> findBatchConfirmation({
    required String batchId,
    required String ownerUserId,
    required String deviceId,
  }) => inner.findBatchConfirmation(
    batchId: batchId,
    ownerUserId: ownerUserId,
    deviceId: deviceId,
  );

  @override
  Future<Either<AppFailure, BackupPublicationResult>> publishBatch(
    BackupBatch batch,
  ) async {
    if (onDuringPublish case final duringHook?) {
      await duringHook();
    }
    final result = await inner.publishBatch(batch);
    if (onAfterPublish case final afterHook?) {
      await afterHook();
    }
    return result;
  }
}

/// Debug-only Drift interceptor that pauses the worker's SQLite `COMMIT` for
/// the acknowledgment transaction so an Android integration test can initiate
/// foreground sign-out while the worker is mid-commit.
class _DebugCommitPauseInterceptor extends QueryInterceptor {
  _DebugCommitPauseInterceptor({required this.onCommitAcknowledgment});

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
    return super.runDelete(executor, statement, args);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    final shouldPause = _sawInFlightDelete;
    _sawInFlightDelete = false;
    if (shouldPause) {
      await onCommitAcknowledgment();
    }
    await super.commitTransaction(inner);
  }

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) async {
    _sawInFlightDelete = false;
    await super.rollbackTransaction(inner);
  }
}

/// Debug-only AuthService reading the synthetic persisted session from
/// [SecureSupabaseLocalStorage] for offline Android worker commit-ordering
/// integration tests without live network traffic.
class _DebugPersistedSessionAuthService implements AuthService {
  _DebugPersistedSessionAuthService(this._storage);

  final SecureSupabaseLocalStorage _storage;
  AuthUser? _cachedUser;

  @override
  bool get isConfigured => true;

  @override
  AuthUser? get currentUser => _cachedUser;

  @override
  Stream<AuthSessionEvent> watchAuthChanges() => const Stream.empty();

  @override
  Future<AuthUser?> getCurrentUser() async {
    final raw = await _storage.accessToken();
    if (raw == null || raw.isEmpty) {
      _cachedUser = null;
      return null;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final userMap = decoded['user'] as Map<String, dynamic>?;
      final id = (userMap?['id'] ?? decoded['user_id']) as String?;
      if (id == null || id.trim().isEmpty) {
        _cachedUser = null;
        return null;
      }
      _cachedUser = AuthUser(
        id: id,
        email: (userMap?['email'] as String?) ?? 'worker-test@example.com',
        shopName: userMap?['shop_name'] as String?,
        emailVerified: true,
      );
      return _cachedUser;
    } catch (_) {
      _cachedUser = null;
      return null;
    }
  }

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
  Future<void> signOut({String? expectedUserId}) async {
    _cachedUser = null;
    await _storage.removePersistedSession();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> resendVerificationEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<void> updatePassword(String newPassword) => throw UnimplementedError();
}

/// Debug-only deterministic cloud publisher for Android worker commit-pause
/// integration tests.
class _DebugDeterministicCloudPublisher implements BackupCloudPublisher {
  _DebugDeterministicCloudPublisher(this._dateService);

  final DateService _dateService;

  @override
  Future<Either<AppFailure, BackupPublicationResult?>> findBatchConfirmation({
    required String batchId,
    required String ownerUserId,
    required String deviceId,
  }) async => const Right(null);

  @override
  Future<Either<AppFailure, BackupPublicationResult>> publishBatch(
    BackupBatch batch,
  ) async => Right(
    BackupPublicationConfirmed(
      batchId: batch.batchId,
      confirmedAt: _dateService.now().toUtc(),
    ),
  );
}
