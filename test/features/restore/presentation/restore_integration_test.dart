import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/connectivity_service.dart';
import 'package:daftariapp/core/utils/app_date_utils.dart';
import 'package:daftariapp/features/auth/session/data/services/ledger_owner_storage.dart';
import 'package:daftariapp/features/auth/session/data/services/secure_gotrue_storage.dart';
import 'package:daftariapp/features/auth/session/data/services/supabase_auth_service.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_session_event.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
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
import 'package:daftariapp/features/restore/data/repositories/drift_restore_local_store.dart';
import 'package:daftariapp/features/restore/data/repositories/restore_repository_impl.dart';
import 'package:daftariapp/features/restore/data/services/restore_transfer_storage.dart';
import 'package:daftariapp/features/restore/domain/entities/restore_entities.dart';
import 'package:daftariapp/features/restore/domain/repositories/restore_cloud_service.dart';
import 'package:daftariapp/features/restore/presentation/cubit/restore_cubit.dart';
import 'package:daftariapp/features/restore/presentation/cubit/restore_state.dart';
import 'package:daftariapp/features/statements/data/repositories/statement_repository_impl.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import '../../backup/domain/backup_domain_fakes.dart';

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

class _DeviceAuthService implements AuthService {
  _DeviceAuthService({this.user});

  final StreamController<AuthSessionEvent> _controller =
      StreamController<AuthSessionEvent>.broadcast();

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
  Future<void> signOut({String? expectedUserId}) async {
    user = null;
    _controller.add(const AuthSessionSignedOut());
  }

  void signIn(AuthUser next) {
    user = next;
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

/// Stateful in-memory cloud server faithful to the Phase 12 + Phase 13 Postgres
/// RPC contracts (`publish_backup_batch`, `find_backup_batch_confirmation`,
/// `read_confirmed_backup_snapshot`, `transfer_backup_authority`, and
/// `find_backup_authority_transfer`).
class _StatefulCloudBackend {
  final Map<String, _CloudAccountLedger> _accounts = {};
  DateTime serverTime = DateTime.utc(2026, 11, 25, 10);

  int readSnapshotCalls = 0;
  int transferAuthorityCalls = 0;
  int findTransferCalls = 0;
  int publishBatchCalls = 0;

  /// When `true`, the next `transferBackupAuthority` call commits the takeover
  /// on the server and then returns `Left(AppFailure(AppErrorCode.network))` to
  /// simulate a lost HTTP response after server commit.
  bool dropNextTransferResponseAfterCommit = false;

  /// When `true`, `findAuthorityTransfer` fails with a network failure to
  /// simulate an unavailable lookup after a lost takeover response.
  bool failFindTransferWithNetwork = false;

  Future<void> Function()? onDuringReadSnapshot;
  Future<void> Function()? onDuringTransferAuthority;

  _CloudAccountLedger? accountFor(String ownerUserId) => _accounts[ownerUserId];

  BackupCloudPublisher publisherForDevice({
    required String Function() readAuthenticatedUserId,
    required String deviceId,
    required String deviceSecret,
  }) => _DeviceCloudPublisher(
    backend: this,
    readAuthenticatedUserId: readAuthenticatedUserId,
    deviceId: deviceId,
    deviceSecret: deviceSecret,
  );

  RestoreCloudService restoreServiceForDevice({
    required AuthUser? Function() readCurrentUser,
    required String deviceId,
    required String deviceSecret,
  }) => _DeviceRestoreCloudService(
    backend: this,
    readCurrentUser: readCurrentUser,
    deviceId: deviceId,
    deviceSecret: deviceSecret,
  );
}

class _CloudAccountLedger {
  _CloudAccountLedger({
    required this.ownerUserId,
    required this.activeDeviceId,
    required this.activeDeviceSecret,
    required this.confirmedAt,
  });

  final String ownerUserId;
  String activeDeviceId;
  String activeDeviceSecret;
  int confirmedVersion = 0;
  DateTime confirmedAt;

  final Map<String, BackupCustomerRecord> customers = {};
  final Map<String, BackupTransactionRecord> transactions = {};
  final Map<String, BackupAuditLogRecord> auditLogs = {};
  final Map<String, (String deviceId, DateTime confirmedAt)> confirmedBatches =
      {};
  final Map<
    String,
    ({
      String targetDeviceId,
      String targetDeviceSecret,
      String version,
      DateTime confirmedAt,
      DateTime transferredAt,
    })
  >
  transfers = {};

  String get versionToken => 'v$confirmedVersion';

  CloudBackupSnapshot buildSnapshot() {
    final sortedCustomers = customers.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedTransactions = transactions.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final sortedAudits = auditLogs.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return CloudBackupSnapshot(
      preview: CloudBackupSnapshotPreview(
        version: versionToken,
        ownerUserId: ownerUserId,
        activeDeviceId: activeDeviceId,
        confirmedAt: confirmedAt,
        customerCount: sortedCustomers.where((c) => !c.isDeleted).length,
        deletedCustomerCount: sortedCustomers.where((c) => c.isDeleted).length,
        transactionCount: sortedTransactions.where((t) => !t.isDeleted).length,
        deletedTransactionCount: sortedTransactions
            .where((t) => t.isDeleted)
            .length,
        auditLogCount: sortedAudits.length,
      ),
      customers: sortedCustomers,
      transactions: sortedTransactions,
      auditLogs: sortedAudits,
    );
  }
}

class _DeviceCloudPublisher implements BackupCloudPublisher {
  _DeviceCloudPublisher({
    required this.backend,
    required this.readAuthenticatedUserId,
    required this.deviceId,
    required this.deviceSecret,
  });

  final _StatefulCloudBackend backend;
  final String Function() readAuthenticatedUserId;
  final String deviceId;
  final String deviceSecret;

  @override
  Future<Either<AppFailure, BackupPublicationResult?>> findBatchConfirmation({
    required String batchId,
    required String ownerUserId,
    required String deviceId,
  }) async {
    final userId = readAuthenticatedUserId();
    final ledger = backend.accountFor(userId);
    if (ledger == null) return const Right(null);
    if (ledger.activeDeviceId != this.deviceId ||
        ledger.activeDeviceSecret != deviceSecret) {
      return const Right(BackupPublicationInactiveDevice());
    }
    final batch = ledger.confirmedBatches[batchId];
    if (batch == null || batch.$1 != this.deviceId) return const Right(null);
    return Right(
      BackupPublicationConfirmed(batchId: batchId, confirmedAt: batch.$2),
    );
  }

  @override
  Future<Either<AppFailure, BackupPublicationResult>> publishBatch(
    BackupBatch batch,
  ) async {
    backend.publishBatchCalls++;
    final userId = readAuthenticatedUserId();
    final now = backend.serverTime.toUtc();
    final ledger = backend._accounts.putIfAbsent(
      userId,
      () => _CloudAccountLedger(
        ownerUserId: userId,
        activeDeviceId: deviceId,
        activeDeviceSecret: deviceSecret,
        confirmedAt: now,
      ),
    );

    if (ledger.activeDeviceId != deviceId ||
        ledger.activeDeviceSecret != deviceSecret) {
      return const Right(BackupPublicationInactiveDevice());
    }

    final existingBatch = ledger.confirmedBatches[batch.batchId];
    if (existingBatch != null) {
      return Right(
        BackupPublicationConfirmed(
          batchId: batch.batchId,
          confirmedAt: existingBatch.$2,
        ),
      );
    }

    for (final c in batch.customers) {
      final current = ledger.customers[c.id];
      if (current == null || c.localRevision >= current.localRevision) {
        ledger.customers[c.id] = c;
      }
    }
    for (final t in batch.transactions) {
      final current = ledger.transactions[t.id];
      if (current == null || t.localRevision >= current.localRevision) {
        ledger.transactions[t.id] = t;
      }
    }
    for (final a in batch.auditLogs) {
      ledger.auditLogs.putIfAbsent(a.id, () => a);
    }

    ledger.confirmedVersion++;
    ledger.confirmedAt = now;
    ledger.confirmedBatches[batch.batchId] = (deviceId, now);

    return Right(
      BackupPublicationConfirmed(batchId: batch.batchId, confirmedAt: now),
    );
  }
}

class _DeviceRestoreCloudService implements RestoreCloudService {
  _DeviceRestoreCloudService({
    required this.backend,
    required this.readCurrentUser,
    required this.deviceId,
    required this.deviceSecret,
  });

  final _StatefulCloudBackend backend;
  final AuthUser? Function() readCurrentUser;
  final String deviceId;
  final String deviceSecret;

  @override
  Future<Either<AppFailure, RestoreCloudSnapshotReadResult>>
  readConfirmedSnapshot({String? expectedVersion}) async {
    backend.readSnapshotCalls++;
    if (backend.onDuringReadSnapshot case final hook?) {
      await hook();
    }
    final user = readCurrentUser();
    if (user == null || !user.emailVerified) {
      return const Left(AppFailure(AppErrorCode.auth));
    }
    final ledger = backend.accountFor(user.id);
    if (ledger == null || ledger.confirmedVersion <= 0) {
      return const Right(RestoreCloudSnapshotMissing());
    }
    final snapshot = ledger.buildSnapshot();
    if (expectedVersion != null &&
        expectedVersion.trim().isNotEmpty &&
        snapshot.preview.version != expectedVersion.trim()) {
      return Right(
        RestoreCloudSnapshotVersionChanged(preview: snapshot.preview),
      );
    }
    return Right(RestoreCloudSnapshotFound(snapshot: snapshot));
  }

  @override
  Future<Either<AppFailure, RestoreAuthorityTransferResult>>
  transferBackupAuthority({
    required String requestId,
    required String targetDeviceId,
    required String expectedVersion,
    required String expectedActiveDeviceId,
  }) async {
    backend.transferAuthorityCalls++;
    if (backend.onDuringTransferAuthority case final hook?) {
      await hook();
    }
    final user = readCurrentUser();
    if (user == null || !user.emailVerified) {
      return const Left(AppFailure(AppErrorCode.auth));
    }
    final ledger = backend.accountFor(user.id);
    if (ledger == null || ledger.confirmedVersion <= 0) {
      return const Right(RestoreAuthorityMissingBackup());
    }

    final existing = ledger.transfers[requestId];
    if (existing != null) {
      if (existing.targetDeviceId != targetDeviceId ||
          existing.targetDeviceSecret != deviceSecret) {
        return const Left(AppFailure(AppErrorCode.auth));
      }
      return Right(
        RestoreAuthorityTransferred(
          requestId: requestId,
          version: existing.version,
          activeDeviceId: existing.targetDeviceId,
          confirmedAt: existing.confirmedAt,
          transferredAt: existing.transferredAt,
        ),
      );
    }

    if (ledger.versionToken != expectedVersion) {
      return Right(
        RestoreAuthorityPreconditionFailed(
          reason: RestorePreconditionFailureReason.versionChanged,
          currentVersion: ledger.versionToken,
          activeDeviceId: ledger.activeDeviceId,
          confirmedAt: ledger.confirmedAt,
        ),
      );
    }

    if (ledger.activeDeviceId != expectedActiveDeviceId) {
      return Right(
        RestoreAuthorityPreconditionFailed(
          reason: RestorePreconditionFailureReason.activeDeviceChanged,
          currentVersion: ledger.versionToken,
          activeDeviceId: ledger.activeDeviceId,
          confirmedAt: ledger.confirmedAt,
        ),
      );
    }

    final now = backend.serverTime.toUtc();
    ledger.activeDeviceId = targetDeviceId;
    ledger.activeDeviceSecret = deviceSecret;
    ledger.transfers[requestId] = (
      targetDeviceId: targetDeviceId,
      targetDeviceSecret: deviceSecret,
      version: ledger.versionToken,
      confirmedAt: ledger.confirmedAt,
      transferredAt: now,
    );

    if (backend.dropNextTransferResponseAfterCommit) {
      backend.dropNextTransferResponseAfterCommit = false;
      return const Left(AppFailure(AppErrorCode.network));
    }

    return Right(
      RestoreAuthorityTransferred(
        requestId: requestId,
        version: ledger.versionToken,
        activeDeviceId: targetDeviceId,
        confirmedAt: ledger.confirmedAt,
        transferredAt: now,
      ),
    );
  }

  @override
  Future<Either<AppFailure, RestoreAuthorityTransferred?>>
  findAuthorityTransfer({
    required String requestId,
    required String targetDeviceId,
  }) async {
    backend.findTransferCalls++;
    if (backend.failFindTransferWithNetwork) {
      return const Left(AppFailure(AppErrorCode.network));
    }
    final user = readCurrentUser();
    if (user == null || !user.emailVerified) {
      return const Left(AppFailure(AppErrorCode.auth));
    }
    final ledger = backend.accountFor(user.id);
    if (ledger == null) return const Right(null);
    final existing = ledger.transfers[requestId];
    if (existing == null ||
        existing.targetDeviceId != targetDeviceId ||
        existing.targetDeviceSecret != deviceSecret) {
      return const Right(null);
    }
    return Right(
      RestoreAuthorityTransferred(
        requestId: requestId,
        version: existing.version,
        activeDeviceId: existing.targetDeviceId,
        confirmedAt: existing.confirmedAt,
        transferredAt: existing.transferredAt,
      ),
    );
  }
}

/// Self-contained simulated Android installation with its own file-backed
/// SQLite database, isolated `FlutterSecureStorage` namespace map, device ID,
/// device secret, `BackupCubit`, and `RestoreCubit`.
class _DeviceHarness {
  _DeviceHarness({
    required this.name,
    required this.dbFile,
    required this.deviceId,
    required this.deviceSecret,
    required this.backend,
    required this.dateService,
    required AuthUser? initialUser,
    String? initialLinkedOwnerId,
  }) : currentUser = initialUser {
    _storageValues[BackupDeviceStorage.secretKeyFor(deviceId)] = deviceSecret;
    if (initialLinkedOwnerId != null) {
      _storageValues[LedgerOwnerStorage.ownerKey] = initialLinkedOwnerId;
    }
    when(() => connectivity.checkConnectivity()).thenAnswer(
      (_) async =>
          isOnline ? [ConnectivityResult.wifi] : [ConnectivityResult.none],
    );
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => connectivityController.stream);
  }

  final String name;
  final File dbFile;
  final String deviceId;
  final String deviceSecret;
  final _StatefulCloudBackend backend;
  final FakeDateService dateService;

  final Map<String, String> _storageValues = {};
  final _MockConnectivity connectivity = _MockConnectivity();
  final StreamController<List<ConnectivityResult>> connectivityController =
      StreamController<List<ConnectivityResult>>.broadcast();
  final StreamController<AuthSessionState> authStateController =
      StreamController<AuthSessionState>.broadcast();
  final StreamController<void> externalChanges =
      StreamController<void>.broadcast();
  final InMemoryBackupRunLock runLock = InMemoryBackupRunLock();
  final _RecordingScheduler scheduler = _RecordingScheduler();

  AuthUser? currentUser;
  bool isOnline = true;

  void setOnline(bool online) {
    isOnline = online;
    connectivityController.add(
      online ? [ConnectivityResult.wifi] : [ConnectivityResult.none],
    );
  }

  AuthSessionState get currentAuthState => currentUser == null
      ? const AuthSessionState(
          initialized: true,
          isConfigured: true,
          status: AuthStatus.unauthenticated,
        )
      : AuthSessionState(
          initialized: true,
          isConfigured: true,
          status: currentUser!.emailVerified
              ? AuthStatus.authenticated
              : AuthStatus.emailVerificationRequired,
          user: currentUser,
          pendingEmail: currentUser!.emailVerified ? null : currentUser!.email,
        );

  /// Binds the FlutterSecureStorage mock channel to this device's storage map
  /// while running an operation or opening an app instance.
  void activateStorageNamespace() {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = (call.arguments as Map<Object?, Object?>?) ?? const {};
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return key == null ? null : _storageValues[key];
            case 'write':
              final value = args['value'] as String?;
              if (key != null && value != null) {
                _storageValues[key] = value;
              }
              return null;
            case 'delete':
              if (key != null) {
                _storageValues.remove(key);
              }
              return null;
            case 'deleteAll':
              _storageValues.clear();
              return null;
            case 'containsKey':
              return key != null && _storageValues.containsKey(key);
            case 'readAll':
              return Map<String, String>.from(_storageValues);
            default:
              return null;
          }
        });
  }

  ({
    AppDatabase db,
    _DeviceAuthService authService,
    RestoreTransferStorage transferStorage,
    DriftBackupLocalStore backupLocalStore,
    DriftRestoreLocalStore restoreLocalStore,
    RestoreRepositoryImpl restoreRepository,
    RunBackupUseCase runBackup,
    UpdateBackupScheduleUseCase updateSchedule,
    BackupCubit backupCubit,
    RestoreCubit restoreCubit,
    StatementRepositoryImpl statementRepository,
    Future<void> Function() dispose,
  })
  openInstance({bool autoTearDown = true}) {
    activateStorageNamespace();
    const secureStorage = FlutterSecureStorage();
    final db = AppDatabase(NativeDatabase(dbFile));
    final authService = _DeviceAuthService(user: currentUser);
    final ownerStorage = LedgerOwnerStorage(secureStorage);
    final deviceStorage = BackupDeviceStorage(
      secureStorage,
      db.backupDao,
      generateDeviceId: () => deviceId,
      generateDeviceSecret: () => deviceSecret,
    );
    final transferStorage = RestoreTransferStorage(secureStorage);
    final connectivityService = ConnectivityService(connectivity);
    final errorHandler = ErrorHandler(
      AppLogger(output: (_) {}, enableCrashReporting: false),
    );

    final backupLocalStore = DriftBackupLocalStore(
      backupDao: db.backupDao,
      authService: authService,
      ownerStorage: ownerStorage,
      deviceStorage: deviceStorage,
      connectivityService: connectivityService,
      errorHandler: errorHandler,
      isBackupRunning: () => runLock.isLocked,
      hasPendingRestoreTransfer: transferStorage.hasPendingTransfer,
      hasPersistedSession: () async => authService.currentUser != null,
      readPersistedSession: () async {
        final u = authService.currentUser;
        if (u == null) return null;
        return PersistedSessionSnapshot(
          userId: u.id,
          isEmailVerified: u.emailVerified,
        );
      },
    );

    final restoreLocalStore = DriftRestoreLocalStore(
      backupDao: db.backupDao,
      authService: authService,
      ownerStorage: ownerStorage,
      deviceStorage: deviceStorage,
      errorHandler: errorHandler,
      hasPersistedSession: () async => authService.currentUser != null,
      readPersistedSession: () async {
        final u = authService.currentUser;
        if (u == null) return null;
        return PersistedSessionSnapshot(
          userId: u.id,
          isEmailVerified: u.emailVerified,
        );
      },
    );

    final cloudPublisher = backend.publisherForDevice(
      readAuthenticatedUserId: () => authService.currentUser!.id,
      deviceId: deviceId,
      deviceSecret: deviceSecret,
    );

    final restoreCloudService = backend.restoreServiceForDevice(
      readCurrentUser: () => authService.currentUser,
      deviceId: deviceId,
      deviceSecret: deviceSecret,
    );

    final runBackup = RunBackupUseCase(
      localStore: backupLocalStore,
      cloudPublisher: cloudPublisher,
      runLock: runLock,
      dateService: dateService,
    );

    final updateSchedule = UpdateBackupScheduleUseCase(
      localStore: backupLocalStore,
      dateService: dateService,
    );

    final backupCubit = BackupCubit(
      runBackup: runBackup,
      updateSchedule: updateSchedule,
      localStore: backupLocalStore,
      scheduler: scheduler,
      runLock: runLock,
      dateService: dateService,
      readAuthState: () => currentAuthState,
      authStateStream: authStateController.stream,
      connectivityStream: connectivityService.onConnectivityChanged,
      externalChangesStream: externalChanges.stream,
    );

    final restoreRepository = RestoreRepositoryImpl(
      localStore: restoreLocalStore,
      cloudService: restoreCloudService,
      transferStorage: transferStorage,
      runLock: runLock,
      scheduler: scheduler,
      authService: authService,
      connectivityService: connectivityService,
      dateService: dateService,
      errorHandler: errorHandler,
      readAuthState: () => currentAuthState,
      hasPersistedSession: () async => authService.currentUser != null,
      readPersistedSession: () async {
        final u = authService.currentUser;
        if (u == null) return null;
        return PersistedSessionSnapshot(
          userId: u.id,
          isEmailVerified: u.emailVerified,
        );
      },
      notifyExternalStateChanged: () async => externalChanges.add(null),
    );

    final restoreCubit = RestoreCubit(
      repository: restoreRepository,
      isPreview: false,
      onRestoreCompleted: backupCubit.refresh,
    );

    final statementRepository = StatementRepositoryImpl(
      db.customerDao,
      db.transactionDao,
      dateService,
      errorHandler,
    );

    var disposed = false;
    Future<void> dispose() async {
      if (disposed) return;
      disposed = true;
      await restoreCubit.close();
      await backupCubit.close();
      await authService.dispose();
      await db.close();
    }

    // Always register idempotent dispose with tearDown so SQLite file handles
    // are guaranteed to close before tempDir deletion even on assertion failure.
    addTearDown(dispose);

    return (
      db: db,
      authService: authService,
      transferStorage: transferStorage,
      backupLocalStore: backupLocalStore,
      restoreLocalStore: restoreLocalStore,
      restoreRepository: restoreRepository,
      runBackup: runBackup,
      updateSchedule: updateSchedule,
      backupCubit: backupCubit,
      restoreCubit: restoreCubit,
      statementRepository: statementRepository,
      dispose: dispose,
    );
  }

  Future<void> disposeHarness() async {
    await connectivityController.close();
    await authStateController.close();
    await externalChanges.close();
  }
}

const _account1User = AuthUser(
  id: 'owner-account-1',
  email: 'account1@example.com',
  shopName: 'Al-Nour Market',
  emailVerified: true,
);

const _account2User = AuthUser(
  id: 'owner-account-2',
  email: 'account2@example.com',
  shopName: 'El-Baraka Store',
  emailVerified: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await AppDateUtils.initialize();
  });

  late Directory tempDir;
  late FakeDateService dateService;
  late _StatefulCloudBackend backend;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('daftari_restore_t4_');
    dateService = FakeDateService(DateTime.utc(2026, 11, 25, 9));
    backend = _StatefulCloudBackend()
      ..serverTime = DateTime.utc(2026, 11, 25, 9, 5);
  });

  tearDown(() async {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  _DeviceHarness createDeviceHarness(
    String name, {
    required String deviceId,
    required String deviceSecret,
    AuthUser? initialUser = _account1User,
    String? initialLinkedOwnerId,
  }) {
    final paddedSecret = deviceSecret.padRight(36, '0');
    final harness = _DeviceHarness(
      name: name,
      dbFile: File('${tempDir.path}${Platform.pathSeparator}$name.sqlite'),
      deviceId: deviceId,
      deviceSecret: paddedSecret,
      backend: backend,
      dateService: dateService,
      initialUser: initialUser,
      initialLinkedOwnerId: initialLinkedOwnerId,
    );
    addTearDown(harness.disposeHarness);
    return harness;
  }

  test('two-device end-to-end flow: publish two batches on A, leave offline edit pending on A, restore and transfer to B, verify customers/balances/statements/tombstones/audits, reject manual and scheduled uploads on A, back up new edit on B, and enforce second-account isolation', () async {
    final deviceAHarness = createDeviceHarness(
      'device_a',
      deviceId: 'device-phone-a',
      deviceSecret: 'secret-phone-a-123456',
      initialUser: _account1User,
      initialLinkedOwnerId: _account1User.id,
    );
    final deviceBHarness = createDeviceHarness(
      'device_b',
      deviceId: 'device-phone-b',
      deviceSecret: 'secret-phone-b-654321',
      initialUser: _account1User,
    );

    // 1. Device A creates initial ledger and publishes Batch 1.
    deviceAHarness.activateStorageNamespace();
    final appA = deviceAHarness.openInstance();
    await appA.backupCubit.initialize();
    await appA.backupCubit.selectSchedule(BackupSchedule.daily);

    final mahmoud = await appA.db.customerDao.createCustomer(
      name: 'Mahmoud',
      phone: '01011112222',
      notes: 'Wholesale buyer',
    );
    final mahmoudCredit1 = await appA.db.transactionDao.createTransaction(
      customerId: mahmoud.id,
      type: TransactionTypes.credit,
      amountPiasters: 50000, // 500 EGP
      note: 'Initial flour sacks',
      transactionDate: DateTime.utc(2026, 11, 20, 10),
    );
    final mahmoudPayment1 = await appA.db.transactionDao.createTransaction(
      customerId: mahmoud.id,
      type: TransactionTypes.payment,
      amountPiasters: 15000, // 150 EGP
      note: 'Cash installment',
      transactionDate: DateTime.utc(2026, 11, 21, 12),
    );

    final samira = await appA.db.customerDao.createCustomer(
      name: 'Samira',
      phone: '01033334444',
    );
    final samiraTx = await appA.db.transactionDao.createTransaction(
      customerId: samira.id,
      type: TransactionTypes.credit,
      amountPiasters: 20000,
      note: 'Sugar order',
      transactionDate: DateTime.utc(2026, 11, 22, 9),
    );
    // Edit Samira's transaction in Batch 1 so Batch 1 already includes an audit entry.
    await appA.db.transactionDao.editTransaction(
      id: samiraTx.id,
      type: TransactionTypes.credit,
      amountPiasters: 24000,
      note: 'Sugar order updated',
      transactionDate: DateTime.utc(2026, 11, 22, 9),
    );

    final deletedCustomer = await appA.db.customerDao.createCustomer(
      name: 'Archived Customer',
    );
    await appA.db.customerDao.softDeleteCustomer(deletedCustomer.id);

    backend.serverTime = DateTime.utc(2026, 11, 25, 9, 10);
    await appA.backupCubit.backUpNow();
    expect(appA.backupCubit.state.status, BackupStatus.upToDate);
    expect(appA.backupCubit.state.pendingChanges, 0);
    expect(backend.accountFor(_account1User.id)!.versionToken, 'v1');

    // 2. Device A makes second set of edits and publishes Batch 2
    // (while leaving Mahmoud's customer row untouched in Batch 2 so we verify
    // cumulative restoration of records last changed in Batch 1!).
    await appA.db.transactionDao.editTransaction(
      id: samiraTx.id,
      type: TransactionTypes.credit,
      amountPiasters: 27500,
      note: 'Sugar order final',
      transactionDate: DateTime.utc(2026, 11, 22, 9),
    );
    final mahmoudDeletedTx = await appA.db.transactionDao.createTransaction(
      customerId: mahmoud.id,
      type: TransactionTypes.credit,
      amountPiasters: 8000,
      note: 'Entered by mistake',
      transactionDate: DateTime.utc(2026, 11, 23, 14),
    );
    await appA.db.transactionDao.softDeleteTransaction(mahmoudDeletedTx.id);

    final fatma = await appA.db.customerDao.createCustomer(
      name: 'Fatma',
      phone: '01299998888',
    );
    await appA.db.transactionDao.createTransaction(
      customerId: fatma.id,
      type: TransactionTypes.credit,
      amountPiasters: 12000,
      note: 'Oil bottles',
      transactionDate: DateTime.utc(2026, 11, 24, 16),
    );

    backend.serverTime = DateTime.utc(2026, 11, 25, 10, 0);
    await appA.backupCubit.backUpNow();
    expect(appA.backupCubit.state.status, BackupStatus.upToDate);
    expect(appA.backupCubit.state.pendingChanges, 0);
    expect(backend.accountFor(_account1User.id)!.versionToken, 'v2');

    // 3. Take Device A offline and create one unconfirmed offline edit on A.
    deviceAHarness.setOnline(false);
    final offlineOnlyTx = await appA.db.transactionDao.createTransaction(
      customerId: mahmoud.id,
      type: TransactionTypes.credit,
      amountPiasters: 99900,
      note: 'Offline pending edit on Phone A',
      transactionDate: DateTime.utc(2026, 11, 25, 10, 15),
    );
    await appA.backupCubit.refresh();
    expect(appA.backupCubit.state.pendingChanges, 1);

    // 4. On Device B (empty new phone), inspect restore preview, confirm
    // combined restore + takeover, and install the confirmed v2 snapshot.
    deviceBHarness.activateStorageNamespace();
    final appB = deviceBHarness.openInstance();
    await appB.backupCubit.initialize();

    await appB.restoreCubit.loadPreview();
    expect(appB.restoreCubit.state.phase, RestorePhase.previewReady);
    expect(appB.restoreCubit.state.requiresTakeover, isTrue);
    expect(appB.restoreCubit.state.requiresReplacement, isFalse);
    expect(appB.restoreCubit.state.cloudPreview!.version, 'v2');
    expect(appB.restoreCubit.state.cloudPreview!.customerCount, 3);
    expect(appB.restoreCubit.state.cloudPreview!.deletedCustomerCount, 1);
    expect(appB.restoreCubit.state.cloudPreview!.transactionCount, 4);
    expect(appB.restoreCubit.state.cloudPreview!.deletedTransactionCount, 1);
    expect(appB.restoreCubit.state.cloudPreview!.auditLogCount, 3);

    appB.restoreCubit.requestRestoreConfirmation();
    expect(appB.restoreCubit.state.phase, RestorePhase.confirmingPrimary);

    backend.serverTime = DateTime.utc(2026, 11, 25, 10, 30);
    await appB.restoreCubit.confirmPrimary();
    expect(appB.restoreCubit.state.phase, RestorePhase.completed);
    expect(appB.restoreCubit.state.authorityTransferred, isTrue);

    // 5. Compare Device B's visible customers, balances, statements,
    // deleted rows (tombstones), and audit history with server-confirmed values.
    final visibleCustomersB = await appB.db.customerDao
        .watchCustomersWithBalances()
        .first;
    expect(visibleCustomersB.map((c) => c.customer.id).toSet(), {
      mahmoud.id,
      samira.id,
      fatma.id,
    });

    final mahmoudOnB = visibleCustomersB.firstWhere(
      (c) => c.customer.id == mahmoud.id,
    );
    // Mahmoud's confirmed balance is 50000 - 15000 = 35000 (excludes A's offline 99900 edit and deleted 8000 tx).
    expect(mahmoudOnB.balancePiasters, 35000);

    final samiraOnB = visibleCustomersB.firstWhere(
      (c) => c.customer.id == samira.id,
    );
    expect(samiraOnB.balancePiasters, 27500);

    final fatmaOnB = visibleCustomersB.firstWhere(
      (c) => c.customer.id == fatma.id,
    );
    expect(fatmaOnB.balancePiasters, 12000);

    final dashboardTotalsB = await appB.db.customerDao
        .watchDashboardTotals()
        .first;
    expect(dashboardTotalsB.activeCustomers, 3);
    expect(dashboardTotalsB.totalCreditPiasters, 50000 + 27500 + 12000);
    expect(dashboardTotalsB.totalPaymentPiasters, 15000);
    expect(dashboardTotalsB.balancePiasters, 35000 + 27500 + 12000);

    // Statement verification on Device B for Mahmoud.
    final mahmoudStatementResult = await appB.statementRepository
        .getCustomerStatement(mahmoud.id);
    final mahmoudStatement = mahmoudStatementResult.getOrElse(
      (_) => throw StateError('Expected Mahmoud statement on B'),
    )!;
    expect(mahmoudStatement.periodCreditPiasters, 50000);
    expect(mahmoudStatement.periodPaymentPiasters, 15000);
    expect(mahmoudStatement.balancePiasters, 35000);
    expect(mahmoudStatement.entries.map((l) => l.id).toSet(), {
      mahmoudCredit1.id,
      mahmoudPayment1.id,
    });

    // Tombstones and complete audit history on Device B match confirmed cloud snapshot.
    final allCustomersB = await appB.db.select(appB.db.customers).get();
    expect(allCustomersB.length, 4);
    final archivedOnB = allCustomersB.firstWhere(
      (c) => c.id == deletedCustomer.id,
    );
    expect(archivedOnB.deletedAt, isNotNull);

    final allTxsB = await appB.db.select(appB.db.transactions).get();
    expect(allTxsB.length, 5);
    expect(allTxsB.any((t) => t.id == offlineOnlyTx.id), isFalse);
    final deletedTxOnB = allTxsB.firstWhere((t) => t.id == mahmoudDeletedTx.id);
    expect(deletedTxOnB.deletedAt, isNotNull);

    final allAuditsB = await appB.db.select(appB.db.transactionAuditLogs).get();
    expect(allAuditsB.length, 3);
    expect(
      allAuditsB.where((a) => a.action == TransactionAuditActions.edit).length,
      2,
    );
    expect(
      allAuditsB
          .where((a) => a.action == TransactionAuditActions.delete)
          .length,
      1,
    );

    // Zero pending restored rows on Device B.
    expect(await appB.db.backupDao.countPendingChanges(), 0);
    expect(appB.backupCubit.state.pendingChanges, 0);
    expect(appB.backupCubit.state.isInactiveDevice, isFalse);

    // 6. Reconnect Device A and exercise BOTH upload triggers (manual and scheduled).
    deviceAHarness.activateStorageNamespace();
    deviceAHarness.setOnline(true);

    // Trigger 1: Manual backup on Device A.
    final publishesBeforeManualA = backend.publishBatchCalls;
    await appA.backupCubit.backUpNow();
    expect(backend.publishBatchCalls, publishesBeforeManualA + 1);
    expect(appA.backupCubit.state.isInactiveDevice, isTrue);
    expect(appA.backupCubit.state.canBackUpNow, isFalse);
    expect(appA.backupCubit.state.pendingChanges, 1);
    expect((await appA.db.backupDao.readMetadata()).isDeviceActive, isFalse);

    // Trigger 2: Queued scheduled worker on Device A (even if metadata were due).
    dateService.current = DateTime.utc(2026, 11, 26, 12);
    final scheduledResultA = await appA.runBackup(
      trigger: BackupTrigger.scheduled,
    );
    expect(
      scheduledResultA.getOrElse((_) => throw StateError('failed')),
      isA<BackupRunSkipped>().having(
        (r) => r.reason,
        'reason',
        BackupIneligibilityReason.inactiveDevice,
      ),
    );
    // Device A still retains its offline edit and can read and edit offline.
    final offlineCustomerOnA = await appA.db.customerDao.createCustomer(
      name: 'Local Only On Former Phone A',
    );
    expect(offlineCustomerOnA.name, 'Local Only On Former Phone A');
    expect(await appA.db.backupDao.countPendingChanges(), 2);
    expect(
      backend.accountFor(_account1User.id)!.activeDeviceId,
      'device-phone-b',
    );

    // 7. Edit on Device B, back up under B's new authority, and inspect cloud result.
    deviceBHarness.activateStorageNamespace();
    await appB.db.transactionDao.createTransaction(
      customerId: mahmoud.id,
      type: TransactionTypes.payment,
      amountPiasters: 5000,
      note: 'Payment recorded on new Phone B',
      transactionDate: DateTime.utc(2026, 11, 26, 13),
    );
    await appB.backupCubit.refresh();
    expect(appB.backupCubit.state.pendingChanges, 1);
    expect(appB.backupCubit.state.canBackUpNow, isTrue);

    backend.serverTime = DateTime.utc(2026, 11, 26, 13, 5);
    await appB.backupCubit.backUpNow();
    expect(appB.backupCubit.state.status, BackupStatus.upToDate);
    expect(appB.backupCubit.state.pendingChanges, 0);

    final cloudAfterB = backend.accountFor(_account1User.id)!.buildSnapshot();
    expect(cloudAfterB.preview.version, 'v3');
    expect(cloudAfterB.preview.activeDeviceId, 'device-phone-b');
    expect(cloudAfterB.preview.transactionCount, 5);

    // 8. Second account verification (isolation).
    final account2DeviceHarness = createDeviceHarness(
      'device_c_account2',
      deviceId: 'device-phone-c',
      deviceSecret: 'secret-phone-c-999999',
      initialUser: _account2User,
    );
    account2DeviceHarness.activateStorageNamespace();
    final appC = account2DeviceHarness.openInstance();
    await appC.restoreCubit.loadPreview();
    // Account 2 has no backup and cannot see Account 1's v3 backup.
    expect(appC.restoreCubit.state.phase, RestorePhase.missingBackup);

    // Signing Account 2 into Device B (whose local ledger is linked to Account 1)
    // blocks restore with accountMismatch.
    deviceBHarness.activateStorageNamespace();
    deviceBHarness.currentUser = _account2User;
    appB.authService.signIn(_account2User);
    await appB.restoreCubit.loadPreview();
    expect(appB.restoreCubit.state.phase, RestorePhase.accountMismatch);
  });

  test('interruption before takeover, after server commit (including lost response), and after local commit recover safely across cold restarts while blocking uploads until completion', () async {
    // Seed confirmed cloud backup from Phone A.
    final deviceAHarness = createDeviceHarness(
      'seed_a',
      deviceId: 'device-seed-a',
      deviceSecret: 'secret-seed-a',
      initialUser: _account1User,
      initialLinkedOwnerId: _account1User.id,
    );
    deviceAHarness.activateStorageNamespace();
    final appA = deviceAHarness.openInstance();
    final seededCustomer = await appA.db.customerDao.createCustomer(
      name: 'Cloud Customer Alpha',
    );
    final seededTx = await appA.db.transactionDao.createTransaction(
      customerId: seededCustomer.id,
      type: TransactionTypes.credit,
      amountPiasters: 45000,
      note: 'Confirmed cloud transaction',
    );
    await appA.db.transactionDao.editTransaction(
      id: seededTx.id,
      type: TransactionTypes.credit,
      amountPiasters: 48000,
      note: 'Confirmed cloud transaction edited',
      transactionDate: seededTx.transactionDate,
    );
    await appA.runBackup(trigger: BackupTrigger.manual);
    await appA.dispose();

    // Receiving Phone B starts with an existing same-account populated ledger
    // (1 local customer + 1 pending local change).
    final deviceBHarness = createDeviceHarness(
      'recover_b',
      deviceId: 'device-recover-b',
      deviceSecret: 'secret-recover-b',
      initialUser: _account1User,
      initialLinkedOwnerId: _account1User.id,
    );
    deviceBHarness.activateStorageNamespace();
    var appB = deviceBHarness.openInstance(autoTearDown: false);
    final localPreExisting = await appB.db.customerDao.createCustomer(
      name: 'Pre-Existing Local Customer B',
    );

    // --- STAGE 1: Interruption BEFORE server takeover ---
    appB.restoreRepository.beforeTakeoverHook = (transfer) async {
      throw RestoreStageInterruption(transfer.stage);
    };

    await appB.restoreCubit.loadPreview();
    expect(appB.restoreCubit.state.phase, RestorePhase.previewReady);
    expect(appB.restoreCubit.state.requiresTakeover, isTrue);
    expect(appB.restoreCubit.state.requiresReplacement, isTrue);

    appB.restoreCubit.requestRestoreConfirmation();
    await appB.restoreCubit.confirmPrimary();
    expect(appB.restoreCubit.state.phase, RestorePhase.confirmingReplacement);

    await appB.restoreCubit.confirmReplacement();
    expect(appB.restoreCubit.state.phase, RestorePhase.interruptedRecovery);
    expect(
      appB.restoreCubit.state.pendingTransfer!.stage,
      RestoreTransferStage.takeoverPending,
    );
    expect(
      appB.restoreCubit.state.pendingTransfer!.canCancelBeforeServerTakeover,
      isTrue,
    );

    // Server authority has NOT changed yet, existing local ledger is intact,
    // and uploads on Phone B are blocked while transfer is pending!
    expect(
      backend.accountFor(_account1User.id)!.activeDeviceId,
      'device-seed-a',
    );
    expect(
      (await appB.db.select(appB.db.customers).get()).single.id,
      localPreExisting.id,
    );
    final blockedManualUpload1 = await appB.runBackup(
      trigger: BackupTrigger.manual,
    );
    expect(
      blockedManualUpload1.getOrElse((_) => throw StateError('failed')),
      isA<BackupRunSkipped>().having(
        (r) => r.reason,
        'reason',
        BackupIneligibilityReason.alreadyRunning,
      ),
    );

    // Simulate cold app restart while interrupted before takeover.
    await appB.dispose();
    appB = deviceBHarness.openInstance(autoTearDown: false);
    await appB.backupCubit.initialize();
    expect(appB.backupCubit.state.canBackUpNow, isFalse);

    await appB.restoreCubit.loadPreview();
    expect(appB.restoreCubit.state.phase, RestorePhase.interruptedRecovery);
    expect(
      appB.restoreCubit.state.pendingTransfer!.stage,
      RestoreTransferStage.takeoverPending,
    );

    // Cancel pre-takeover interrupted transfer -> unblocks uploads and leaves
    // existing local ledger intact.
    await appB.restoreCubit.cancelInterruptedTransfer();
    expect(appB.restoreCubit.state.phase, RestorePhase.previewReady);
    expect(await appB.transferStorage.hasPendingTransfer(), isFalse);
    await appB.backupCubit.refresh();
    expect(appB.backupCubit.state.canBackUpNow, isTrue);

    // --- STAGE 2A: Server commits takeover, network response is LOST ---
    backend.dropNextTransferResponseAfterCommit = true;
    appB.restoreCubit.requestRestoreConfirmation();
    await appB.restoreCubit.confirmPrimary();
    await appB.restoreCubit.confirmReplacement();

    // Server committed takeover to device-recover-b, but response was lost!
    expect(
      backend.accountFor(_account1User.id)!.activeDeviceId,
      'device-recover-b',
    );
    expect(appB.restoreCubit.state.phase, RestorePhase.interruptedRecovery);

    // Simulate cold restart and also pause after takeover confirmation before
    // local install (Stage 2B) on next resume.
    await appB.dispose();
    appB = deviceBHarness.openInstance(autoTearDown: false);

    // On restart, inspectRestore() probes findAuthorityTransfer for the same
    // requestId, discovers the server already committed, and upgrades the
    // persisted transfer stage to takeoverConfirmed!
    await appB.restoreCubit.loadPreview();
    expect(appB.restoreCubit.state.phase, RestorePhase.interruptedRecovery);
    expect(
      appB.restoreCubit.state.pendingTransfer!.stage,
      RestoreTransferStage.takeoverConfirmed,
    );
    expect(
      appB.restoreCubit.state.pendingTransfer!.canCancelBeforeServerTakeover,
      isFalse,
    );
    // Pre-existing local ledger is still intact before local install commits,
    // and uploads remain blocked on Phone B.
    expect(
      (await appB.db.select(appB.db.customers).get()).single.id,
      localPreExisting.id,
    );
    final blockedScheduledUpload2 = await appB.runBackup(
      trigger: BackupTrigger.scheduled,
    );
    expect(
      blockedScheduledUpload2.getOrElse((_) => throw StateError('failed')),
      isA<BackupRunSkipped>().having(
        (r) => r.reason,
        'reason',
        BackupIneligibilityReason.alreadyRunning,
      ),
    );

    // --- STAGE 3: Interruption AFTER local SQLite commit (before clearing pending transfer) ---
    final transferBeforeResume = appB.restoreCubit.state.pendingTransfer!;
    await appB.dispose();
    appB = deviceBHarness.openInstance(autoTearDown: false);
    appB.restoreRepository.afterLocalCommitBeforeClearHook = (transfer) async {
      throw RestoreStageInterruption(transfer.stage);
    };

    final postLocalCommitAttempt = await appB.restoreRepository
        .resumePendingTransfer(transferBeforeResume);
    expect(
      postLocalCommitAttempt.getOrElse((_) => throw StateError('failed')),
      isA<RestoreExecutionInterrupted>(),
    );
    // SQLite has already committed the restored rows, while the pending
    // transfer marker is still persisted on disk.
    expect(await appB.transferStorage.hasPendingTransfer(), isTrue);
    expect(
      (await appB.db.select(appB.db.customers).get()).single.id,
      seededCustomer.id,
    );

    // Simulate cold restart after local commit interruption and resume to
    // completion.
    await appB.dispose();
    appB = deviceBHarness.openInstance(autoTearDown: false);
    await appB.restoreCubit.loadPreview();
    expect(appB.restoreCubit.state.phase, RestorePhase.interruptedRecovery);
    expect(
      appB.restoreCubit.state.pendingTransfer!.stage,
      RestoreTransferStage.installingLocally,
    );

    final transfersCountBeforeFinalResume = backend.transferAuthorityCalls;
    await appB.restoreCubit.resumeInterruptedTransfer();
    expect(appB.restoreCubit.state.phase, RestorePhase.completed);
    expect(await appB.transferStorage.hasPendingTransfer(), isFalse);
    // Idempotent recovery did not issue a new transfer call and did not
    // duplicate any records or audit history.
    expect(backend.transferAuthorityCalls, transfersCountBeforeFinalResume);
    expect((await appB.db.select(appB.db.customers).get()).length, 1);
    expect((await appB.db.select(appB.db.transactions).get()).length, 1);
    expect(
      (await appB.db.select(appB.db.transactionAuditLogs).get()).length,
      1,
    );
    expect(await appB.db.backupDao.countPendingChanges(), 0);

    await appB.dispose();
  });

  test('duplicate taps, concurrent backup worker exclusion, account changes, and foreground edits after preview are coordinated safely', () async {
    // Seed cloud backup v1 from Phone A.
    final deviceAHarness = createDeviceHarness(
      'coord_a',
      deviceId: 'device-coord-a',
      deviceSecret: 'secret-coord-a',
      initialUser: _account1User,
      initialLinkedOwnerId: _account1User.id,
    );
    deviceAHarness.activateStorageNamespace();
    final appA = deviceAHarness.openInstance();
    await appA.db.customerDao.createCustomer(name: 'Cloud Customer V1');
    await appA.runBackup(trigger: BackupTrigger.manual);
    await appA.dispose();

    final deviceBHarness = createDeviceHarness(
      'coord_b',
      deviceId: 'device-coord-b',
      deviceSecret: 'secret-coord-b',
      initialUser: _account1User,
    );
    deviceBHarness.activateStorageNamespace();
    final appB = deviceBHarness.openInstance();

    // 1. Edit after preview on an initially empty ledger invalidates consent
    // and refreshes preview requiring two-step replacement confirmation.
    await appB.restoreCubit.loadPreview();
    expect(appB.restoreCubit.state.phase, RestorePhase.previewReady);
    expect(appB.restoreCubit.state.requiresReplacement, isFalse);

    appB.restoreCubit.requestRestoreConfirmation();
    expect(appB.restoreCubit.state.phase, RestorePhase.confirmingPrimary);

    // Foreground edit occurs before confirmPrimary executes!
    final localCustomer = await appB.db.customerDao.createCustomer(
      name: 'Foreground Edit After Preview',
    );

    await appB.restoreCubit.confirmPrimary();
    expect(appB.restoreCubit.state.phase, RestorePhase.previewReady);
    expect(
      appB.restoreCubit.state.refreshReason,
      RestoreRefreshReason.localLedgerChanged,
    );
    expect(appB.restoreCubit.state.requiresReplacement, isTrue);
    expect(appB.restoreCubit.state.localLedger!.customerCount, 1);
    expect(appB.restoreCubit.state.localLedger!.pendingChangesCount, 1);
    // Local edit is preserved and takeover was not executed.
    expect(
      (await appB.db.select(appB.db.customers).get()).single.id,
      localCustomer.id,
    );
    expect(
      backend.accountFor(_account1User.id)!.activeDeviceId,
      'device-coord-a',
    );

    // 2. Edit after primary confirmation (before confirmReplacement) on a
    // populated ledger also invalidates prior replacement consent.
    appB.restoreCubit.requestRestoreConfirmation();
    await appB.restoreCubit.confirmPrimary();
    expect(appB.restoreCubit.state.phase, RestorePhase.confirmingReplacement);

    await appB.db.transactionDao.createTransaction(
      customerId: localCustomer.id,
      type: TransactionTypes.credit,
      amountPiasters: 10000,
    );

    await appB.restoreCubit.confirmReplacement();
    expect(appB.restoreCubit.state.phase, RestorePhase.previewReady);
    expect(
      appB.restoreCubit.state.refreshReason,
      RestoreRefreshReason.localLedgerChanged,
    );
    expect(appB.restoreCubit.state.localLedger!.transactionCount, 1);
    expect(appB.restoreCubit.state.localLedger!.pendingChangesCount, 2);

    // 3. Sign-out during confirmation blocks execution and preserves local data.
    appB.restoreCubit.requestRestoreConfirmation();
    await appB.restoreCubit.confirmPrimary();
    expect(appB.restoreCubit.state.phase, RestorePhase.confirmingReplacement);

    await appB.authService.signOut();
    deviceBHarness.currentUser = null;
    await appB.restoreCubit.confirmReplacement();
    expect(appB.restoreCubit.state.phase, RestorePhase.error);
    expect((await appB.db.select(appB.db.customers).get()).length, 1);
    expect((await appB.db.select(appB.db.transactions).get()).length, 1);

    // Sign back in and reload preview.
    deviceBHarness.currentUser = _account1User;
    appB.authService.signIn(_account1User);
    await appB.restoreCubit.loadPreview();
    expect(appB.restoreCubit.state.phase, RestorePhase.previewReady);

    // 4. Duplicate taps & worker exclusion while takeover is in flight.
    appB.restoreCubit.requestRestoreConfirmation();
    await appB.restoreCubit.confirmPrimary();
    expect(appB.restoreCubit.state.phase, RestorePhase.confirmingReplacement);

    final transferEntered = Completer<void>();
    final releaseTransfer = Completer<void>();
    backend.onDuringTransferAuthority = () async {
      if (!transferEntered.isCompleted) transferEntered.complete();
      await releaseTransfer.future;
    };

    final transfersBefore = backend.transferAuthorityCalls;
    final token = appB.restoreCubit.state
        .copyWith(primaryConfirmed: true, replacementConfirmed: true)
        .buildConsentToken()!;

    // Fire two overlapping executeRestore calls + a duplicate cubit tap.
    final execFuture1 = appB.restoreCubit.confirmReplacement();
    final execFuture2 = appB.restoreRepository.executeRestore(consent: token);
    await transferEntered.future;

    // While restore holds BackupRunLock, a background scheduled backup worker
    // is excluded immediately with alreadyRunning.
    final concurrentWorkerResult = await appB.runBackup(
      trigger: BackupTrigger.scheduled,
    );
    expect(
      concurrentWorkerResult.getOrElse((_) => throw StateError('failed')),
      isA<BackupRunSkipped>().having(
        (r) => r.reason,
        'reason',
        BackupIneligibilityReason.alreadyRunning,
      ),
    );

    backend.onDuringTransferAuthority = null;
    releaseTransfer.complete();
    await execFuture1;
    final duplicateResult = await execFuture2;

    expect(appB.restoreCubit.state.phase, RestorePhase.completed);
    expect(
      duplicateResult.getOrElse((_) => throw StateError('failed')),
      isA<RestoreExecutionSucceeded>(),
    );
    // Only one server takeover call was executed despite duplicate calls.
    expect(backend.transferAuthorityCalls - transfersBefore, 1);
    expect(
      (await appB.db.select(appB.db.customers).get()).single.name,
      'Cloud Customer V1',
    );
  });

  test('P13-01: lost takeover response disables Cancel immediately and across restart when lookup fails, keeps manual and scheduled uploads blocked, and recovers when connectivity returns', () async {
    final deviceAHarness = createDeviceHarness(
      'p13_01_a',
      deviceId: 'device-p13-01-a',
      deviceSecret: 'secret-p13-01-a',
      initialUser: _account1User,
      initialLinkedOwnerId: _account1User.id,
    );
    deviceAHarness.activateStorageNamespace();
    final appA = deviceAHarness.openInstance();
    final cloudCustomer = await appA.db.customerDao.createCustomer(
      name: 'P13-01 Confirmed Customer',
    );
    await appA.runBackup(trigger: BackupTrigger.manual);
    await appA.dispose();

    final deviceBHarness = createDeviceHarness(
      'p13_01_b',
      deviceId: 'device-p13-01-b',
      deviceSecret: 'secret-p13-01-b',
      initialUser: _account1User,
      initialLinkedOwnerId: _account1User.id,
    );
    deviceBHarness.activateStorageNamespace();
    var appB = deviceBHarness.openInstance();
    final localOldCustomer = await appB.db.customerDao.createCustomer(
      name: 'P13-01 Old Local Customer On B',
    );
    await appB.backupCubit.initialize();
    await appB.backupCubit.selectSchedule(BackupSchedule.daily);

    // 1. Verify cancellation still works before the takeover request is sent.
    appB.restoreRepository.beforeTakeoverHook = (transfer) async {
      throw RestoreStageInterruption(transfer.stage);
    };
    await appB.restoreCubit.loadPreview();
    appB.restoreCubit.requestRestoreConfirmation();
    await appB.restoreCubit.confirmPrimary();
    await appB.restoreCubit.confirmReplacement();
    expect(appB.restoreCubit.state.phase, RestorePhase.interruptedRecovery);
    expect(
      appB.restoreCubit.state.pendingTransfer!.canCancelBeforeServerTakeover,
      isTrue,
    );
    await appB.restoreCubit.cancelInterruptedTransfer();
    expect(appB.restoreCubit.state.phase, RestorePhase.previewReady);
    expect(await appB.transferStorage.hasPendingTransfer(), isFalse);
    appB.restoreRepository.beforeTakeoverHook = null;

    // 2. Drop a committed takeover response and tap Cancel immediately.
    backend.dropNextTransferResponseAfterCommit = true;
    backend.failFindTransferWithNetwork = true;
    appB.restoreCubit.requestRestoreConfirmation();
    await appB.restoreCubit.confirmPrimary();
    await appB.restoreCubit.confirmReplacement();

    expect(
      backend.accountFor(_account1User.id)!.activeDeviceId,
      'device-p13-01-b',
    );
    expect(appB.restoreCubit.state.phase, RestorePhase.interruptedRecovery);
    final lostResponseTransfer = appB.restoreCubit.state.pendingTransfer!;
    expect(lostResponseTransfer.stage, RestoreTransferStage.takeoverPending);
    expect(lostResponseTransfer.isTakeoverOutcomeUnknown, isTrue);
    expect(lostResponseTransfer.canCancelBeforeServerTakeover, isFalse);

    // Tapping Cancel immediately (both via Cubit and directly via Repository)
    // must NOT discard the staged transfer or unblock uploads.
    await appB.restoreCubit.cancelInterruptedTransfer();
    final directDiscard1 = await appB.restoreRepository.discardPendingTransfer(
      lostResponseTransfer.requestId,
    );
    expect(directDiscard1.isLeft(), isTrue);
    expect(await appB.transferStorage.hasPendingTransfer(), isTrue);

    final publishesBefore1 = backend.publishBatchCalls;
    await appB.backupCubit.backUpNow();
    dateService.current = DateTime.utc(2026, 11, 27, 10);
    final scheduled1 = await appB.runBackup(trigger: BackupTrigger.scheduled);
    expect(
      scheduled1.getOrElse((_) => throw StateError('failed')),
      isA<BackupRunSkipped>().having(
        (r) => r.reason,
        'reason',
        BackupIneligibilityReason.alreadyRunning,
      ),
    );
    expect(backend.publishBatchCalls, publishesBefore1);

    // 3. Restart with the lookup still unavailable -> Cancel remains disabled
    // and uploads remain blocked.
    await appB.dispose();
    appB = deviceBHarness.openInstance();
    await appB.backupCubit.initialize();
    await appB.restoreCubit.loadPreview();
    expect(appB.restoreCubit.state.phase, RestorePhase.interruptedRecovery);
    expect(
      appB.restoreCubit.state.pendingTransfer!.canCancelBeforeServerTakeover,
      isFalse,
    );
    await appB.restoreCubit.cancelInterruptedTransfer();
    final directDiscard2 = await appB.restoreRepository.discardPendingTransfer(
      lostResponseTransfer.requestId,
    );
    expect(directDiscard2.isLeft(), isTrue);
    expect(await appB.transferStorage.hasPendingTransfer(), isTrue);

    await appB.backupCubit.backUpNow();
    final scheduled2 = await appB.runBackup(trigger: BackupTrigger.scheduled);
    expect(
      scheduled2.getOrElse((_) => throw StateError('failed')),
      isA<BackupRunSkipped>().having(
        (r) => r.reason,
        'reason',
        BackupIneligibilityReason.alreadyRunning,
      ),
    );
    expect(backend.publishBatchCalls, publishesBefore1);
    expect(
      (await appB.db.select(appB.db.customers).get()).single.id,
      localOldCustomer.id,
    );

    // 4. Restore lookup connectivity -> the same request recovers and
    // installs the cloud snapshot.
    backend.failFindTransferWithNetwork = false;
    final transfersBeforeResume = backend.transferAuthorityCalls;
    await appB.restoreCubit.resumeInterruptedTransfer();
    expect(appB.restoreCubit.state.phase, RestorePhase.completed);
    expect(backend.transferAuthorityCalls, transfersBeforeResume);
    expect(await appB.transferStorage.hasPendingTransfer(), isFalse);
    expect(
      (await appB.db.select(appB.db.customers).get()).single.id,
      cloudCustomer.id,
    );
  });

  test('P13-02: local edit after takeover preserves edited ledger and upload block across restart until owner reconfirms replacement (including after lost takeover response and failing lookup)', () async {
    final deviceAHarness = createDeviceHarness(
      'p13_02_a',
      deviceId: 'device-p13-02-a',
      deviceSecret: 'secret-p13-02-a',
      initialUser: _account1User,
      initialLinkedOwnerId: _account1User.id,
    );
    deviceAHarness.activateStorageNamespace();
    final appA = deviceAHarness.openInstance();
    final cloudCustomer = await appA.db.customerDao.createCustomer(
      name: 'P13-02 Cloud Customer',
    );
    await appA.runBackup(trigger: BackupTrigger.manual);
    await appA.dispose();

    // Part 1: Edit on B after server takeover confirmation, before SQLite transaction.
    final deviceBHarness = createDeviceHarness(
      'p13_02_b',
      deviceId: 'device-p13-02-b',
      deviceSecret: 'secret-p13-02-b',
      initialUser: _account1User,
      initialLinkedOwnerId: _account1User.id,
    );
    deviceBHarness.activateStorageNamespace();
    var appB = deviceBHarness.openInstance();
    await appB.db.customerDao.createCustomer(name: 'Old Customer 1 On B');
    await appB.backupCubit.initialize();
    await appB.backupCubit.selectSchedule(BackupSchedule.daily);

    await appB.restoreCubit.loadPreview();
    appB.restoreCubit.requestRestoreConfirmation();
    await appB.restoreCubit.confirmPrimary();

    // Inject local edit on B AFTER server confirms takeover but BEFORE the
    // SQLite replacement transaction runs.
    appB.restoreRepository.afterTakeoverBeforeLocalInstallHook = (_) async {
      await appB.db.customerDao.createCustomer(
        name: 'Edited Customer 2 Post-Takeover On B',
      );
    };

    await appB.restoreCubit.confirmReplacement();
    appB.restoreRepository.afterTakeoverBeforeLocalInstallHook = null;

    // Takeover committed on server, Drift rejected replacement because of
    // the new edit, edited ledger is intact, and upload block is PRESERVED!
    expect(
      backend.accountFor(_account1User.id)!.activeDeviceId,
      'device-p13-02-b',
    );
    expect(appB.restoreCubit.state.phase, RestorePhase.previewReady);
    expect(
      appB.restoreCubit.state.refreshReason,
      RestoreRefreshReason.localLedgerChanged,
    );
    expect((await appB.db.select(appB.db.customers).get()).length, 2);
    expect(await appB.transferStorage.hasPendingTransfer(), isTrue);

    // Leave the screen, restart, and try manual and due scheduled backup:
    // neither may publish rows from B's old ledger!
    await appB.dispose();
    appB = deviceBHarness.openInstance();
    await appB.backupCubit.initialize();
    dateService.current = DateTime.utc(2026, 11, 27, 12);

    final publishesBeforeAttempt = backend.publishBatchCalls;
    expect(appB.backupCubit.state.canBackUpNow, isFalse);
    await appB.backupCubit.backUpNow();
    final scheduledOnB = await appB.runBackup(trigger: BackupTrigger.scheduled);
    expect(
      scheduledOnB.getOrElse((_) => throw StateError('failed')),
      isA<BackupRunSkipped>().having(
        (r) => r.reason,
        'reason',
        BackupIneligibilityReason.alreadyRunning,
      ),
    );
    expect(backend.publishBatchCalls, publishesBeforeAttempt);

    // Reopen Restore screen, resume -> prompts for fresh replacement consent,
    // reconfirm -> installation succeeds and clears upload block.
    await appB.restoreCubit.loadPreview();
    expect(appB.restoreCubit.state.phase, RestorePhase.interruptedRecovery);
    await appB.restoreCubit.resumeInterruptedTransfer();
    expect(appB.restoreCubit.state.phase, RestorePhase.previewReady);
    expect(
      appB.restoreCubit.state.refreshReason,
      RestoreRefreshReason.localLedgerChanged,
    );
    expect(await appB.transferStorage.hasPendingTransfer(), isTrue);

    appB.restoreCubit.requestRestoreConfirmation();
    await appB.restoreCubit.confirmPrimary();
    await appB.restoreCubit.confirmReplacement();
    expect(appB.restoreCubit.state.phase, RestorePhase.completed);
    expect(await appB.transferStorage.hasPendingTransfer(), isFalse);
    expect(
      (await appB.db.select(appB.db.customers).get()).single.id,
      cloudCustomer.id,
    );
    await appB.dispose();

    // Part 2: Repeat with a lost takeover response, a local edit on C, and
    // a failing lookup.
    final deviceCHarness = createDeviceHarness(
      'p13_02_c',
      deviceId: 'device-p13-02-c',
      deviceSecret: 'secret-p13-02-c',
      initialUser: _account1User,
      initialLinkedOwnerId: _account1User.id,
    );
    deviceCHarness.activateStorageNamespace();
    var appC = deviceCHarness.openInstance();
    await appC.db.customerDao.createCustomer(name: 'Old Customer On C');
    await appC.backupCubit.initialize();
    await appC.backupCubit.selectSchedule(BackupSchedule.daily);

    backend.dropNextTransferResponseAfterCommit = true;
    await appC.restoreCubit.loadPreview();
    appC.restoreCubit.requestRestoreConfirmation();
    await appC.restoreCubit.confirmPrimary();
    await appC.restoreCubit.confirmReplacement();
    expect(appC.restoreCubit.state.phase, RestorePhase.interruptedRecovery);
    expect(
      backend.accountFor(_account1User.id)!.activeDeviceId,
      'device-p13-02-c',
    );

    // Edit local ledger on C after lost takeover response, then fail lookup.
    await appC.db.customerDao.createCustomer(
      name: 'Local Edit After Lost Takeover Response On C',
    );
    backend.failFindTransferWithNetwork = true;

    // Restart and attempt resume while lookup fails -> must NOT delete
    // transfer or clear upload block!
    await appC.dispose();
    appC = deviceCHarness.openInstance();
    await appC.backupCubit.initialize();
    await appC.restoreCubit.loadPreview();
    await appC.restoreCubit.resumeInterruptedTransfer();
    expect(appC.restoreCubit.state.phase, RestorePhase.interruptedRecovery);
    expect(await appC.transferStorage.hasPendingTransfer(), isTrue);

    await appC.backupCubit.backUpNow();
    final scheduledOnC = await appC.runBackup(trigger: BackupTrigger.scheduled);
    expect(
      scheduledOnC.getOrElse((_) => throw StateError('failed')),
      isA<BackupRunSkipped>().having(
        (r) => r.reason,
        'reason',
        BackupIneligibilityReason.alreadyRunning,
      ),
    );
    expect(backend.publishBatchCalls, publishesBeforeAttempt);

    // Restore lookup, resume -> transitions to previewReady for fresh
    // replacement consent while keeping upload block active, then reconfirm!
    backend.failFindTransferWithNetwork = false;
    await appC.restoreCubit.resumeInterruptedTransfer();
    expect(appC.restoreCubit.state.phase, RestorePhase.previewReady);
    expect(
      appC.restoreCubit.state.refreshReason,
      RestoreRefreshReason.localLedgerChanged,
    );
    expect(await appC.transferStorage.hasPendingTransfer(), isTrue);

    appC.restoreCubit.requestRestoreConfirmation();
    await appC.restoreCubit.confirmPrimary();
    await appC.restoreCubit.confirmReplacement();
    expect(appC.restoreCubit.state.phase, RestorePhase.completed);
    expect(await appC.transferStorage.hasPendingTransfer(), isFalse);
    expect(
      (await appC.db.select(appC.db.customers).get()).single.id,
      cloudCustomer.id,
    );
  });

  test('P13-04: cancelling a pre-takeover request and submitting its stale Resume action issues no takeover, installs no rows, and leaves a newer persisted request intact', () async {
    final deviceAHarness = createDeviceHarness(
      'p13_04_a',
      deviceId: 'device-p13-04-a',
      deviceSecret: 'secret-p13-04-a',
      initialUser: _account1User,
      initialLinkedOwnerId: _account1User.id,
    );
    deviceAHarness.activateStorageNamespace();
    final appA = deviceAHarness.openInstance();
    await appA.db.customerDao.createCustomer(name: 'P13-04 Cloud Customer');
    await appA.runBackup(trigger: BackupTrigger.manual);
    await appA.dispose();

    final deviceBHarness = createDeviceHarness(
      'p13_04_b',
      deviceId: 'device-p13-04-b',
      deviceSecret: 'secret-p13-04-b',
      initialUser: _account1User,
    );
    deviceBHarness.activateStorageNamespace();
    final appB = deviceBHarness.openInstance();

    // Interrupt request 1 before takeover.
    appB.restoreRepository.beforeTakeoverHook = (transfer) async {
      throw RestoreStageInterruption(transfer.stage);
    };
    await appB.restoreCubit.loadPreview();
    appB.restoreCubit.requestRestoreConfirmation();
    await appB.restoreCubit.confirmPrimary();
    expect(appB.restoreCubit.state.phase, RestorePhase.interruptedRecovery);
    final staleRequest1 = appB.restoreCubit.state.pendingTransfer!;
    appB.restoreRepository.beforeTakeoverHook = null;

    // 1. Overlap discard and stale resume for request 1:
    // discard wins first, stale resume sees no matching durable request ID
    // and aborts with zero takeovers and zero installed rows.
    final transfersBefore = backend.transferAuthorityCalls;
    final discardFuture = appB.restoreRepository.discardPendingTransfer(
      staleRequest1.requestId,
    );
    final staleResumeFuture1 = appB.restoreRepository.resumePendingTransfer(
      staleRequest1,
    );
    final discardRes = await discardFuture;
    final staleResumeRes1 = await staleResumeFuture1;
    expect(discardRes.isRight(), isTrue);
    expect(staleResumeRes1.isLeft(), isTrue);
    expect(backend.transferAuthorityCalls, transfersBefore);
    expect(await appB.db.select(appB.db.customers).get(), isEmpty);

    // 2. Persist a newer request (request 2) for the same version (v1) and
    // submit the stale Resume action for cancelled request 1.
    appB.restoreRepository.beforeTakeoverHook = (transfer) async {
      throw RestoreStageInterruption(transfer.stage);
    };
    await appB.restoreCubit.loadPreview();
    appB.restoreCubit.requestRestoreConfirmation();
    await appB.restoreCubit.confirmPrimary();
    final newerRequest2 = appB.restoreCubit.state.pendingTransfer!;
    expect(newerRequest2.requestId, isNot(staleRequest1.requestId));
    expect(newerRequest2.expectedVersion, staleRequest1.expectedVersion);
    appB.restoreRepository.beforeTakeoverHook = null;

    final staleResumeRes2 = await appB.restoreRepository.resumePendingTransfer(
      staleRequest1,
    );
    expect(staleResumeRes2.isLeft(), isTrue);
    expect(backend.transferAuthorityCalls, transfersBefore);
    expect(await appB.db.select(appB.db.customers).get(), isEmpty);

    // Newer request 2 remains completely intact in storage and can resume
    // normally.
    final persistedAfterStale = await appB.transferStorage
        .readPendingTransfer();
    expect(persistedAfterStale, isNotNull);
    expect(persistedAfterStale!.transfer.requestId, newerRequest2.requestId);

    final validResume = await appB.restoreRepository.resumePendingTransfer(
      newerRequest2,
    );
    expect(validResume.isRight(), isTrue);
    expect(backend.transferAuthorityCalls, transfersBefore + 1);
    expect((await appB.db.select(appB.db.customers).get()).length, 1);
  });
}
