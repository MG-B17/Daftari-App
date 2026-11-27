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
import '../../backup/data/services/android_backup_platform_bridge.dart';
import '../../backup/data/services/backup_device_storage.dart';
import '../../backup/domain/repositories/backup_run_lock.dart';
import '../../backup/domain/repositories/backup_scheduler.dart';
import '../../backup/presentation/cubit/backup_cubit.dart';
import '../data/repositories/drift_restore_local_store.dart';
import '../data/repositories/restore_repository_impl.dart';
import '../data/repositories/supabase_restore_cloud_service.dart';
import '../data/services/restore_transfer_storage.dart';
import '../domain/repositories/restore_cloud_service.dart';
import '../domain/repositories/restore_local_store.dart';
import '../domain/repositories/restore_repository.dart';
import '../presentation/cubit/restore_cubit.dart';

void registerRestoreDependencies(GetIt sl) {
  if (!sl.isRegistered<RestoreTransferStorage>()) {
    sl.registerLazySingleton<RestoreTransferStorage>(
      () => RestoreTransferStorage(sl<FlutterSecureStorage>()),
    );
  }
  if (!sl.isRegistered<RestoreLocalStore>()) {
    sl.registerLazySingleton<RestoreLocalStore>(() {
      final persistedSessionStorage = SecureSupabaseLocalStorage(
        sl<FlutterSecureStorage>(),
      );
      return DriftRestoreLocalStore(
        backupDao: sl<BackupDao>(),
        authService: sl<AuthService>(),
        ownerStorage: sl<LedgerOwnerStorage>(),
        deviceStorage: sl<BackupDeviceStorage>(),
        errorHandler: sl<ErrorHandler>(),
        commitGate: sl<SessionCommitGate>(),
        hasPersistedSession: persistedSessionStorage.hasAccessToken,
        readPersistedSession: persistedSessionStorage.readSessionSnapshot,
      );
    });
  }
  if (!sl.isRegistered<RestoreCloudService>()) {
    sl.registerLazySingleton<RestoreCloudService>(
      () => SupabaseRestoreCloudService(
        bootstrap: sl<SupabaseBootstrap>(),
        authService: sl<AuthService>(),
        deviceStorage: sl<BackupDeviceStorage>(),
        errorHandler: sl<ErrorHandler>(),
      ),
    );
  }
  if (!sl.isRegistered<RestoreRepository>()) {
    sl.registerLazySingleton<RestoreRepository>(() {
      final persistedSessionStorage = SecureSupabaseLocalStorage(
        sl<FlutterSecureStorage>(),
      );
      return RestoreRepositoryImpl(
        localStore: sl<RestoreLocalStore>(),
        cloudService: sl<RestoreCloudService>(),
        transferStorage: sl<RestoreTransferStorage>(),
        runLock: sl<BackupRunLock>(),
        scheduler: sl<BackupScheduler>(),
        authService: sl<AuthService>(),
        connectivityService: sl<ConnectivityService>(),
        dateService: sl<DateService>(),
        errorHandler: sl<ErrorHandler>(),
        readAuthState: () => sl<AuthSessionCubit>().state,
        hasPersistedSession: persistedSessionStorage.hasAccessToken,
        readPersistedSession: persistedSessionStorage.readSessionSnapshot,
        notifyExternalStateChanged:
            sl<AndroidBackupPlatformBridge>().notifyBackupStateChanged,
      );
    });
  }
  if (!sl.isRegistered<RestoreCubit>()) {
    sl.registerFactory<RestoreCubit>(
      () => RestoreCubit(
        repository: sl<RestoreRepository>(),
        isPreview: false,
        onRestoreCompleted: () => sl<BackupCubit>().refresh(),
      ),
    );
  }
}
