import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/services/connectivity/connectivity_service.dart';
import '../../../core/services/date/date_service.dart';
import '../../../core/services/session_commit_gate/session_commit_gate.dart';
import '../../auth/session/data/services/ledger_owner_storage.dart';
import '../../auth/session/data/services/secure_gotrue_storage.dart';
import '../../auth/session/data/services/supabase_auth_service.dart';
import '../../auth/session/data/services/supabase_bootstrap.dart';
import '../../auth/session/presentation/cubit/auth_session_cubit.dart';
import '../../restore/data/services/restore_transfer_storage.dart';
import '../data/repositories/drift_backup_local_store.dart';
import '../data/repositories/supabase_backup_cloud_publisher.dart';
import '../data/services/android_backup_platform_bridge.dart';
import '../data/services/backup_device_storage.dart';
import '../domain/repositories/backup_cloud_publisher.dart';
import '../domain/repositories/backup_local_store.dart';
import '../domain/repositories/backup_run_lock.dart';
import '../domain/repositories/backup_scheduler.dart';
import '../domain/usecases/run_backup_usecase.dart';
import '../domain/usecases/update_backup_schedule_usecase.dart';
import '../presentation/cubit/backup_cubit.dart';

void registerBackupDependencies(GetIt sl) {
  if (!sl.isRegistered<AndroidBackupPlatformBridge>()) {
    sl.registerLazySingleton<AndroidBackupPlatformBridge>(
      AndroidBackupPlatformBridge.new,
      dispose: (bridge) => bridge.dispose(),
    );
  }
  if (!sl.isRegistered<BackupRunLock>()) {
    sl.registerLazySingleton<BackupRunLock>(
      () => sl<AndroidBackupPlatformBridge>(),
    );
  }
  if (!sl.isRegistered<BackupScheduler>()) {
    sl.registerLazySingleton<BackupScheduler>(
      () => sl<AndroidBackupPlatformBridge>(),
    );
  }
  if (!sl.isRegistered<BackupDeviceStorage>()) {
    sl.registerLazySingleton<BackupDeviceStorage>(
      () => BackupDeviceStorage(sl<FlutterSecureStorage>(), sl<BackupDao>()),
    );
  }
  if (!sl.isRegistered<BackupLocalStore>()) {
    sl.registerLazySingleton<BackupLocalStore>(() {
      final persistedSessionStorage = SecureSupabaseLocalStorage(
        sl<FlutterSecureStorage>(),
      );
      return DriftBackupLocalStore(
        backupDao: sl<BackupDao>(),
        authService: sl<AuthService>(),
        ownerStorage: sl<LedgerOwnerStorage>(),
        deviceStorage: sl<BackupDeviceStorage>(),
        connectivityService: sl<ConnectivityService>(),
        errorHandler: sl<ErrorHandler>(),
        commitGate: sl<SessionCommitGate>(),
        isBackupRunning: () => sl<BackupRunLock>().isLocked,
        hasPendingRestoreTransfer:
            sl<RestoreTransferStorage>().hasPendingTransfer,
        hasPersistedSession: persistedSessionStorage.hasAccessToken,
        readPersistedSession: persistedSessionStorage.readSessionSnapshot,
      );
    });
  }
  if (!sl.isRegistered<BackupCloudPublisher>()) {
    sl.registerLazySingleton<BackupCloudPublisher>(
      () => SupabaseBackupCloudPublisher(
        bootstrap: sl<SupabaseBootstrap>(),
        authService: sl<AuthService>(),
        deviceStorage: sl<BackupDeviceStorage>(),
        errorHandler: sl<ErrorHandler>(),
      ),
    );
  }
  if (!sl.isRegistered<RunBackupUseCase>()) {
    sl.registerLazySingleton<RunBackupUseCase>(
      () => RunBackupUseCase(
        localStore: sl<BackupLocalStore>(),
        cloudPublisher: sl<BackupCloudPublisher>(),
        runLock: sl<BackupRunLock>(),
        dateService: sl<DateService>(),
      ),
    );
  }
  if (!sl.isRegistered<UpdateBackupScheduleUseCase>()) {
    sl.registerLazySingleton<UpdateBackupScheduleUseCase>(
      () => UpdateBackupScheduleUseCase(
        localStore: sl<BackupLocalStore>(),
        dateService: sl<DateService>(),
      ),
    );
  }
  if (!sl.isRegistered<BackupCubit>()) {
    sl.registerLazySingleton<BackupCubit>(
      () => BackupCubit(
        runBackup: sl<RunBackupUseCase>(),
        updateSchedule: sl<UpdateBackupScheduleUseCase>(),
        localStore: sl<BackupLocalStore>(),
        scheduler: sl<BackupScheduler>(),
        runLock: sl<BackupRunLock>(),
        dateService: sl<DateService>(),
        readAuthState: () => sl<AuthSessionCubit>().state,
        authStateStream: sl<AuthSessionCubit>().stream,
        connectivityStream: sl<ConnectivityService>().onConnectivityChanged,
        localChangesStream: _watchLocalBackupChanges(sl<BackupDao>()),
        externalChangesStream:
            sl<AndroidBackupPlatformBridge>().onExternalBackupStateChanged,
        checkRemoteRunLocked:
            sl<AndroidBackupPlatformBridge>().refreshRemoteRunLocked,
      ),
      dispose: (cubit) => cubit.close(),
    );
  }
}

Stream<void> _watchLocalBackupChanges(BackupDao dao) {
  late StreamController<void> controller;
  StreamSubscription<Object?>? metadataSub;
  StreamSubscription<Object?>? pendingSub;
  controller = StreamController<void>.broadcast(
    onListen: () {
      metadataSub ??= dao.watchMetadata().listen(
        (_) => controller.add(null),
        onError: (_) {},
      );
      pendingSub ??= dao.watchPendingChangesCount().listen(
        (_) => controller.add(null),
        onError: (_) {},
      );
    },
    onCancel: () async {
      await metadataSub?.cancel();
      await pendingSub?.cancel();
      metadataSub = null;
      pendingSub = null;
    },
  );
  return controller.stream;
}
