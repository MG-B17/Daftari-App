import 'dart:async';
import 'dart:ui' show Locale;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../features/auth/di/auth_di.dart';
import '../../features/auth/forgot_password/presentation/cubit/forgot_password_cubit.dart';
import '../../features/auth/login/presentation/cubit/login_cubit.dart';
import '../../features/auth/session/data/services/ledger_owner_storage.dart';
import '../../features/auth/session/data/services/secure_gotrue_storage.dart';
import '../../features/auth/session/data/services/supabase_auth_service.dart';
import '../../features/auth/session/data/services/supabase_bootstrap.dart';
import '../../features/auth/session/presentation/cubit/auth_session_cubit.dart';
import '../../features/auth/sign_up/presentation/cubit/sign_up_cubit.dart';
import '../../features/auth/update_password/presentation/cubit/update_password_cubit.dart';
import '../../features/auth/verify_email/presentation/cubit/verify_email_cubit.dart';
import '../../features/backup/data/repositories/drift_backup_local_store.dart';
import '../../features/backup/data/repositories/supabase_backup_cloud_publisher.dart';
import '../../features/backup/data/services/android_backup_platform_bridge.dart';
import '../../features/backup/data/services/backup_device_storage.dart';
import '../../features/backup/domain/repositories/backup_cloud_publisher.dart';
import '../../features/backup/domain/repositories/backup_local_store.dart';
import '../../features/backup/domain/repositories/backup_run_lock.dart';
import '../../features/backup/domain/repositories/backup_scheduler.dart';
import '../../features/backup/domain/usecases/run_backup_usecase.dart';
import '../../features/backup/domain/usecases/update_backup_schedule_usecase.dart';
import '../../features/backup/presentation/cubit/backup_cubit.dart';
import '../../features/restore/data/repositories/drift_restore_local_store.dart';
import '../../features/restore/data/repositories/restore_repository_impl.dart';
import '../../features/restore/data/repositories/supabase_restore_cloud_service.dart';
import '../../features/restore/data/services/restore_transfer_storage.dart';
import '../../features/restore/domain/repositories/restore_cloud_service.dart';
import '../../features/restore/domain/repositories/restore_local_store.dart';
import '../../features/restore/domain/repositories/restore_repository.dart';
import '../../features/restore/presentation/cubit/restore_cubit.dart';
import '../../features/customers/di/customers_di.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/dashboard/di/dashboard_di.dart';
import '../../features/search/di/search_di.dart';
import '../../features/search/presentation/cubit/search_cubit.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';
import '../../features/security/data/repositories/security_repository_impl.dart';
import '../../features/security/data/services/biometric_auth_service.dart';
import '../../features/security/data/services/secure_storage_service.dart';
import '../../features/security/domain/repositories/security_repository.dart';
import '../../features/security/presentation/cubit/app_lock_cubit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/usecases/get_settings_usecase.dart';
import '../../features/settings/domain/usecases/change_language_usecase.dart';
import '../../features/statements/di/statements_di.dart';
import '../../features/transactions/di/transactions_di.dart';
import '../database/app_database.dart';
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import '../routing/app_router.dart';
import '../services/app_logger.dart';
import '../services/connectivity_service.dart';
import '../services/contact_picker_service.dart';
import '../services/date_service.dart';
import '../services/local_storage_service.dart';
import '../services/session_commit_gate.dart';
import '../services/widget_image_exporter.dart';
import '../theme/theme_switcher_cubit.dart';
import '../utils/app_date_utils.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  if (!sl.isRegistered<SharedPreferences>()) {
    final SharedPreferences preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      throw const StorageException();
    }
    // Recheck after awaiting: simultaneous bootstrap calls must be safe too.
    if (!sl.isRegistered<SharedPreferences>()) {
      sl.registerSingleton<SharedPreferences>(preferences);
    }
  }
  await AppDateUtils.initialize();
  if (!sl.isRegistered<DateService>()) {
    sl.registerLazySingleton<DateService>(SystemDateService.new);
  }
  if (!sl.isRegistered<LocalStorageService>()) {
    sl.registerLazySingleton<LocalStorageService>(
      () => LocalStorageService(sl<SharedPreferences>()),
    );
  }
  if (!sl.isRegistered<ConnectivityService>()) {
    sl.registerLazySingleton<ConnectivityService>(
      () => ConnectivityService(Connectivity()),
    );
  }
  if (!sl.isRegistered<AppLogger>()) {
    sl.registerLazySingleton<AppLogger>(
      () => AppLogger(
        crashReporter: (error, stack, {required fatal}) => FirebaseCrashlytics
            .instance
            .recordError(error, stack, fatal: fatal, printDetails: false),
      ),
    );
  }
  if (!sl.isRegistered<ErrorHandler>()) {
    sl.registerLazySingleton<ErrorHandler>(() => ErrorHandler(sl<AppLogger>()));
  }
  if (!sl.isRegistered<FlutterSecureStorage>()) {
    sl.registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(
        aOptions: AndroidOptions(resetOnError: false),
      ),
    );
  }
  if (!sl.isRegistered<LocalAuthentication>()) {
    sl.registerLazySingleton<LocalAuthentication>(LocalAuthentication.new);
  }
  if (!sl.isRegistered<SecureStorageService>()) {
    sl.registerLazySingleton<SecureStorageService>(
      () => SecureStorageService(sl<FlutterSecureStorage>()),
    );
  }
  if (!sl.isRegistered<BiometricAuthService>()) {
    sl.registerLazySingleton<BiometricAuthService>(
      () => BiometricAuthService(
        sl<LocalAuthentication>(),
        biometricReason: () =>
            lookupAppLocalizations(Locale(sl<LocalStorageService>().localeCode))
                .securityBiometricAction,
        recoveryReason: () =>
            lookupAppLocalizations(Locale(sl<LocalStorageService>().localeCode))
                .securityRecoveryTitle,
      ),
    );
  }
  if (!sl.isRegistered<SecurityRepository>()) {
    sl.registerLazySingleton<SecurityRepository>(
      () => SecurityRepositoryImpl(
        sl<SecureStorageService>(),
        sl<BiometricAuthService>(),
        sl<LocalStorageService>(),
        sl<DateService>(),
        sl<ErrorHandler>(),
      ),
    );
  }
  if (!sl.isRegistered<AppDatabase>()) {
    sl.registerLazySingleton<AppDatabase>(
      AppDatabase.new,
      dispose: (database) => database.close(),
    );
  }
  if (!sl.isRegistered<CustomerDao>()) {
    sl.registerLazySingleton<CustomerDao>(() => sl<AppDatabase>().customerDao);
  }
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
  if (!sl.isRegistered<SessionCommitGate>()) {
    sl.registerLazySingleton<SessionCommitGate>(
      () => SessionCommitGate(coordinator: sl<AndroidBackupPlatformBridge>()),
    );
  }
  registerAuthDependencies(sl);
  if (!sl.isRegistered<TransactionDao>()) {
    sl.registerLazySingleton<TransactionDao>(
      () => sl<AppDatabase>().transactionDao,
    );
  }
  if (!sl.isRegistered<BackupDao>()) {
    sl.registerLazySingleton<BackupDao>(() => sl<AppDatabase>().backupDao);
  }
  if (!sl.isRegistered<BackupDeviceStorage>()) {
    sl.registerLazySingleton<BackupDeviceStorage>(
      () => BackupDeviceStorage(sl<FlutterSecureStorage>(), sl<BackupDao>()),
    );
  }
  if (!sl.isRegistered<RestoreTransferStorage>()) {
    sl.registerLazySingleton<RestoreTransferStorage>(
      () => RestoreTransferStorage(sl<FlutterSecureStorage>()),
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
  if (!sl.isRegistered<ContactPickerService>()) {
    sl.registerLazySingleton<ContactPickerService>(ContactPickerService.new);
  }
  registerCustomersDependencies(sl);
  registerTransactionsDependencies(sl);
  registerDashboardDependencies(sl);
  if (!sl.isRegistered<WidgetImageExporter>()) {
    sl.registerLazySingleton<WidgetImageExporter>(WidgetImageExporter.new);
  }
  registerStatementsDependencies(sl);
  registerSearchDependencies(sl);
  if (!sl.isRegistered<OnboardingCubit>()) {
    sl.registerFactory<OnboardingCubit>(
      () => OnboardingCubit(sl<LocalStorageService>()),
    );
  }
  if (!sl.isRegistered<SettingsRepository>()) {
    sl.registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(sl<LocalStorageService>()),
    );
  }
  if (!sl.isRegistered<GetSettingsUseCase>()) {
    sl.registerLazySingleton<GetSettingsUseCase>(
      () => GetSettingsUseCase(sl<SettingsRepository>()),
    );
  }
  if (!sl.isRegistered<ChangeLanguageUseCase>()) {
    sl.registerLazySingleton<ChangeLanguageUseCase>(
      () => ChangeLanguageUseCase(sl<SettingsRepository>()),
    );
  }
  if (!sl.isRegistered<ThemeSwitcherCubit>()) {
    sl.registerLazySingleton<ThemeSwitcherCubit>(
      () => ThemeSwitcherCubit(sl<LocalStorageService>(), sl<ErrorHandler>()),
      dispose: (cubit) => cubit.close(),
    );
  }
  if (!sl.isRegistered<SettingsCubit>()) {
    sl.registerLazySingleton<SettingsCubit>(
      () => SettingsCubit(
        sl<GetSettingsUseCase>(),
        sl<ChangeLanguageUseCase>(),
        sl<ErrorHandler>(),
      ),
      dispose: (cubit) => cubit.close(),
    );
  }
  if (!sl.isRegistered<AppLockCubit>()) {
    sl.registerLazySingleton<AppLockCubit>(
      () => AppLockCubit(sl<SecurityRepository>(), sl<DateService>()),
      dispose: (cubit) => cubit.close(),
    );
  }
  await Future.wait([
    sl<AppLockCubit>().initialize(),
    sl<SupabaseBootstrap>()
        .initialize(sl<FlutterSecureStorage>())
        .then((_) => sl<AuthSessionCubit>().initialize()),
  ]);
  if (!sl.isRegistered<GoRouter>()) {
    sl.registerLazySingleton<GoRouter>(
      () => AppRouter.create(
        localStorage: sl<LocalStorageService>(),
        appLock: sl<AppLockCubit>(),
        authSessionCubit: sl<AuthSessionCubit>(),
        createOnboardingCubit: () => sl<OnboardingCubit>(),
        createLoginCubit: () => sl<LoginCubit>(),
        createSignUpCubit: () => sl<SignUpCubit>(),
        createForgotPasswordCubit: () => sl<ForgotPasswordCubit>(),
        createVerifyEmailCubit: () => sl<VerifyEmailCubit>(),
        createUpdatePasswordCubit: () => sl<UpdatePasswordCubit>(),
        createRestoreCubit: () => sl<RestoreCubit>(),
        createSearchCubit: () => sl<SearchCubit>(),
      ),
      dispose: (router) => router.dispose(),
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
