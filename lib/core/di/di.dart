import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/di/auth_di.dart';
import '../../features/auth/forgot_password/presentation/cubit/forgot_password_cubit.dart';
import '../../features/auth/login/presentation/cubit/login_cubit.dart';
import '../../features/auth/session/data/services/supabase_bootstrap.dart';
import '../../features/auth/session/presentation/cubit/auth_session_cubit.dart';
import '../../features/auth/sign_up/presentation/cubit/sign_up_cubit.dart';
import '../../features/auth/update_password/presentation/cubit/update_password_cubit.dart';
import '../../features/auth/verify_email/presentation/cubit/verify_email_cubit.dart';
import '../../features/backup/data/services/android_backup_platform_bridge.dart';
import '../../features/backup/di/backup_di.dart';
import '../../features/restore/di/restore_di.dart';
import '../../features/restore/presentation/cubit/restore_cubit.dart';
import '../../features/customers/di/customers_di.dart';
import '../../features/dashboard/di/dashboard_di.dart';
import '../../features/layout/di/layout_di.dart';
import '../../features/onboarding/di/onboarding_di.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/search/di/search_di.dart';
import '../../features/search/presentation/cubit/search_cubit.dart';
import '../../features/security/di/security_di.dart';
import '../../features/security/presentation/cubit/app_lock_cubit.dart';
import '../../features/settings/di/settings_di.dart';
import '../../features/splash/di/splash_di.dart';
import '../../features/statements/di/statements_di.dart';
import '../../features/transactions/di/transactions_di.dart';
import '../database/app_database.dart';
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import '../routing/app_router.dart';
import '../services/logger/app_logger.dart';
import '../services/connectivity/connectivity_service.dart';
import '../services/contact_picker/contact_picker_service.dart';
import '../services/date/date_service.dart';
import '../services/loacl_storage/local_storage_service.dart';
import '../services/session_commit_gate/session_commit_gate.dart';
import '../services/image_exporter/widget_image_exporter.dart';
import '../theme/theme_controller/theme_switcher_cubit.dart';
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
  registerSecurityDependencies(sl);
  if (!sl.isRegistered<AppDatabase>()) {
    sl.registerLazySingleton<AppDatabase>(
      AppDatabase.new,
      dispose: (database) => database.close(),
    );
  }
  if (!sl.isRegistered<CustomerDao>()) {
    sl.registerLazySingleton<CustomerDao>(() => sl<AppDatabase>().customerDao);
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
  registerBackupDependencies(sl);
  registerRestoreDependencies(sl);
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
  registerOnboardingDependencies(sl);
  registerLayoutDependencies(sl);
  if (!sl.isRegistered<ThemeSwitcherCubit>()) {
    sl.registerLazySingleton<ThemeSwitcherCubit>(
      () => ThemeSwitcherCubit(sl<LocalStorageService>(), sl<ErrorHandler>()),
      dispose: (cubit) => cubit.close(),
    );
  }
  registerSettingsDependencies(sl);
  registerSplashDependencies(sl);
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
