import 'dart:async';
import 'dart:ui' show Locale;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../features/auth/forgot_password/data/repositories/forgot_password_repository_impl.dart';
import '../../features/auth/forgot_password/domain/repositories/forgot_password_repository.dart';
import '../../features/auth/forgot_password/domain/usecases/send_password_reset_usecase.dart';
import '../../features/auth/forgot_password/presentation/cubit/forgot_password_cubit.dart';
import '../../features/auth/login/data/repositories/login_repository_impl.dart';
import '../../features/auth/login/domain/repositories/login_repository.dart';
import '../../features/auth/login/domain/usecases/sign_in_usecase.dart';
import '../../features/auth/login/presentation/cubit/login_cubit.dart';
import '../../features/auth/session/data/repositories/auth_session_repository_impl.dart';
import '../../features/auth/session/data/services/auth_error_mapper.dart';
import '../../features/auth/session/data/services/ledger_owner_storage.dart';
import '../../features/auth/session/data/services/secure_gotrue_storage.dart';
import '../../features/auth/session/data/services/supabase_auth_service.dart';
import '../../features/auth/session/data/services/supabase_bootstrap.dart';
import '../../features/auth/session/domain/repositories/auth_session_coordinator.dart';
import '../../features/auth/session/domain/repositories/auth_session_repository.dart';
import '../../features/auth/session/domain/usecases/confirm_ledger_link_usecase.dart';
import '../../features/auth/session/domain/usecases/sign_out_usecase.dart';
import '../../features/auth/session/presentation/cubit/auth_session_cubit.dart';
import '../../features/auth/sign_up/data/repositories/sign_up_repository_impl.dart';
import '../../features/auth/sign_up/domain/repositories/sign_up_repository.dart';
import '../../features/auth/sign_up/domain/usecases/sign_up_usecase.dart';
import '../../features/auth/sign_up/presentation/cubit/sign_up_cubit.dart';
import '../../features/auth/update_password/data/repositories/update_password_repository_impl.dart';
import '../../features/auth/update_password/domain/repositories/update_password_repository.dart';
import '../../features/auth/update_password/domain/usecases/update_password_usecase.dart';
import '../../features/auth/update_password/presentation/cubit/update_password_cubit.dart';
import '../../features/auth/verify_email/data/repositories/verify_email_repository_impl.dart';
import '../../features/auth/verify_email/domain/repositories/verify_email_repository.dart';
import '../../features/auth/verify_email/domain/usecases/check_email_verified_usecase.dart';
import '../../features/auth/verify_email/domain/usecases/resend_verification_email_usecase.dart';
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
import '../../features/customers/data/repositories/customer_repository_impl.dart';
import '../../features/customers/domain/repositories/customer_repository.dart';
import '../../features/customers/domain/usecases/create_customer_usecase.dart';
import '../../features/customers/domain/usecases/pick_contact_usecase.dart';
import '../../features/customers/domain/usecases/soft_delete_customer_usecase.dart';
import '../../features/customers/domain/usecases/update_customer_usecase.dart';
import '../../features/customers/domain/usecases/watch_customer_details_usecase.dart';
import '../../features/customers/domain/usecases/watch_customers_usecase.dart';
import '../../features/customers/presentation/cubit/customer_details_cubit.dart';
import '../../features/customers/presentation/cubit/customer_form_cubit.dart';
import '../../features/customers/presentation/cubit/customers_list_cubit.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/dashboard/domain/usecases/watch_dashboard_summary_usecase.dart';
import '../../features/dashboard/presentation/cubit/dashboard_cubit.dart';
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
import '../../features/settings/domain/usecases/change_theme_usecase.dart';
import '../../features/statements/data/repositories/statement_repository_impl.dart';
import '../../features/statements/data/services/statement_share_service.dart';
import '../../features/statements/domain/repositories/statement_repository.dart';
import '../../features/statements/domain/usecases/get_customer_statement_usecase.dart';
import '../../features/statements/presentation/cubit/statement_cubit.dart';
import '../../features/statements/presentation/services/statement_image_renderer.dart';
import '../../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../../features/transactions/domain/repositories/transaction_repository.dart';
import '../../features/transactions/domain/usecases/create_transaction_usecase.dart';
import '../../features/transactions/domain/usecases/edit_transaction_usecase.dart';
import '../../features/transactions/domain/usecases/get_transaction_by_id_usecase.dart';
import '../../features/transactions/domain/usecases/soft_delete_transaction_usecase.dart';
import '../../features/transactions/domain/usecases/watch_customer_transactions_usecase.dart';
import '../../features/transactions/presentation/cubit/customer_transactions_cubit.dart';
import '../../features/transactions/presentation/cubit/transaction_form_cubit.dart';
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
  if (!sl.isRegistered<SupabaseBootstrap>()) {
    sl.registerLazySingleton<SupabaseBootstrap>(SupabaseBootstrap.new);
  }
  await sl<SupabaseBootstrap>().initialize(sl<FlutterSecureStorage>());
  if (!sl.isRegistered<LedgerOwnerStorage>()) {
    sl.registerLazySingleton<LedgerOwnerStorage>(
      () => LedgerOwnerStorage(
        sl<FlutterSecureStorage>(),
        readDurableOwnerId: () => sl<BackupDao>().readDurableOwnerId(),
        claimDurableOwnerId: (ownerUserId) =>
            sl<BackupDao>().claimOrReadDurableOwnerId(ownerUserId),
      ),
    );
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
  if (!sl.isRegistered<AuthService>()) {
    sl.registerLazySingleton<AuthService>(
      () => SupabaseAuthService(
        sl<SupabaseBootstrap>(),
        commitGate: sl<SessionCommitGate>(),
      ),
    );
  }
  if (!sl.isRegistered<AuthErrorMapper>()) {
    sl.registerLazySingleton<AuthErrorMapper>(
      () => AuthErrorMapper(sl<ErrorHandler>()),
    );
  }
  if (!sl.isRegistered<AuthSessionRepository>()) {
    sl.registerLazySingleton<AuthSessionRepository>(
      () => AuthSessionRepositoryImpl(
        sl<AuthService>(),
        sl<LedgerOwnerStorage>(),
        () => sl<CustomerDao>().hasAnyCustomers(),
        sl<AuthErrorMapper>(),
      ),
    );
  }
  if (!sl.isRegistered<SignOutUseCase>()) {
    sl.registerLazySingleton<SignOutUseCase>(
      () => SignOutUseCase(sl<AuthSessionRepository>()),
    );
  }
  if (!sl.isRegistered<ConfirmLedgerLinkUseCase>()) {
    sl.registerLazySingleton<ConfirmLedgerLinkUseCase>(
      () => ConfirmLedgerLinkUseCase(sl<AuthSessionRepository>()),
    );
  }
  if (!sl.isRegistered<AuthSessionCubit>()) {
    sl.registerLazySingleton<AuthSessionCubit>(
      () => AuthSessionCubit(
        sl<AuthSessionRepository>(),
        sl<SignOutUseCase>(),
        sl<ConfirmLedgerLinkUseCase>(),
      ),
      dispose: (cubit) => cubit.close(),
    );
  }
  if (!sl.isRegistered<AuthSessionCoordinator>()) {
    sl.registerLazySingleton<AuthSessionCoordinator>(
      () => sl<AuthSessionCubit>(),
    );
  }
  if (!sl.isRegistered<LoginRepository>()) {
    sl.registerLazySingleton<LoginRepository>(
      () => LoginRepositoryImpl(sl<AuthService>(), sl<AuthErrorMapper>()),
    );
  }
  if (!sl.isRegistered<SignInUseCase>()) {
    sl.registerLazySingleton<SignInUseCase>(
      () => SignInUseCase(sl<LoginRepository>(), sl<AuthSessionRepository>()),
    );
  }
  if (!sl.isRegistered<LoginCubit>()) {
    sl.registerFactory<LoginCubit>(
      () => LoginCubit(sl<SignInUseCase>(), sl<AuthSessionCoordinator>()),
    );
  }
  if (!sl.isRegistered<SignUpRepository>()) {
    sl.registerLazySingleton<SignUpRepository>(
      () => SignUpRepositoryImpl(sl<AuthService>(), sl<AuthErrorMapper>()),
    );
  }
  if (!sl.isRegistered<SignUpUseCase>()) {
    sl.registerLazySingleton<SignUpUseCase>(
      () => SignUpUseCase(sl<SignUpRepository>(), sl<AuthSessionRepository>()),
    );
  }
  if (!sl.isRegistered<SignUpCubit>()) {
    sl.registerFactory<SignUpCubit>(
      () => SignUpCubit(sl<SignUpUseCase>(), sl<AuthSessionCoordinator>()),
    );
  }
  if (!sl.isRegistered<ForgotPasswordRepository>()) {
    sl.registerLazySingleton<ForgotPasswordRepository>(
      () => ForgotPasswordRepositoryImpl(
        sl<AuthService>(),
        sl<AuthErrorMapper>(),
      ),
    );
  }
  if (!sl.isRegistered<SendPasswordResetUseCase>()) {
    sl.registerLazySingleton<SendPasswordResetUseCase>(
      () => SendPasswordResetUseCase(sl<ForgotPasswordRepository>()),
    );
  }
  if (!sl.isRegistered<ForgotPasswordCubit>()) {
    sl.registerFactory<ForgotPasswordCubit>(
      () => ForgotPasswordCubit(
        sl<SendPasswordResetUseCase>(),
        sl<AuthSessionCoordinator>(),
      ),
    );
  }
  if (!sl.isRegistered<VerifyEmailRepository>()) {
    sl.registerLazySingleton<VerifyEmailRepository>(
      () => VerifyEmailRepositoryImpl(sl<AuthService>(), sl<AuthErrorMapper>()),
    );
  }
  if (!sl.isRegistered<ResendVerificationEmailUseCase>()) {
    sl.registerLazySingleton<ResendVerificationEmailUseCase>(
      () => ResendVerificationEmailUseCase(sl<VerifyEmailRepository>()),
    );
  }
  if (!sl.isRegistered<CheckEmailVerifiedUseCase>()) {
    sl.registerLazySingleton<CheckEmailVerifiedUseCase>(
      () => CheckEmailVerifiedUseCase(
        sl<VerifyEmailRepository>(),
        sl<AuthSessionRepository>(),
      ),
    );
  }
  if (!sl.isRegistered<VerifyEmailCubit>()) {
    sl.registerFactory<VerifyEmailCubit>(
      () => VerifyEmailCubit(
        sl<ResendVerificationEmailUseCase>(),
        sl<CheckEmailVerifiedUseCase>(),
        sl<AuthSessionCoordinator>(),
      ),
    );
  }
  if (!sl.isRegistered<UpdatePasswordRepository>()) {
    sl.registerLazySingleton<UpdatePasswordRepository>(
      () => UpdatePasswordRepositoryImpl(
        sl<AuthService>(),
        sl<AuthErrorMapper>(),
      ),
    );
  }
  if (!sl.isRegistered<UpdatePasswordUseCase>()) {
    sl.registerLazySingleton<UpdatePasswordUseCase>(
      () => UpdatePasswordUseCase(sl<UpdatePasswordRepository>()),
    );
  }
  if (!sl.isRegistered<UpdatePasswordCubit>()) {
    sl.registerFactory<UpdatePasswordCubit>(
      () => UpdatePasswordCubit(
        sl<UpdatePasswordUseCase>(),
        sl<AuthSessionCoordinator>(),
      ),
    );
  }
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
  if (!sl.isRegistered<CustomerRepository>()) {
    sl.registerLazySingleton<CustomerRepository>(
      () => CustomerRepositoryImpl(
        sl<CustomerDao>(),
        sl<ContactPickerService>(),
        sl<ErrorHandler>(),
      ),
    );
  }
  if (!sl.isRegistered<TransactionRepository>()) {
    sl.registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(sl<TransactionDao>(), sl<ErrorHandler>()),
    );
  }
  if (!sl.isRegistered<DashboardRepository>()) {
    sl.registerLazySingleton<DashboardRepository>(
      () => DashboardRepositoryImpl(
        sl<CustomerDao>(),
        sl<TransactionDao>(),
        sl<ErrorHandler>(),
        sl<DateService>(),
      ),
    );
  }
  if (!sl.isRegistered<StatementRepository>()) {
    sl.registerLazySingleton<StatementRepository>(
      () => StatementRepositoryImpl(
        sl<CustomerDao>(),
        sl<TransactionDao>(),
        sl<DateService>(),
        sl<ErrorHandler>(),
      ),
    );
  }
  if (!sl.isRegistered<GetCustomerStatementUseCase>()) {
    sl.registerLazySingleton<GetCustomerStatementUseCase>(
      () => GetCustomerStatementUseCase(sl<StatementRepository>()),
    );
  }
  if (!sl.isRegistered<WidgetImageExporter>()) {
    sl.registerLazySingleton<WidgetImageExporter>(WidgetImageExporter.new);
  }
  if (!sl.isRegistered<StatementImageRenderer>()) {
    sl.registerLazySingleton<StatementImageRenderer>(
      () => WidgetStatementImageRenderer(sl<WidgetImageExporter>()),
    );
  }
  if (!sl.isRegistered<StatementShareService>()) {
    sl.registerLazySingleton<StatementShareService>(
      () => StatementShareService(sl<ErrorHandler>()),
    );
  }
  if (!sl.isRegistered<StatementCubit>()) {
    sl.registerFactory(
      () => StatementCubit(
        sl<GetCustomerStatementUseCase>(),
        sl<StatementShareService>(),
        sl<StatementImageRenderer>(),
      ),
    );
  }
  if (!sl.isRegistered<WatchDashboardSummaryUseCase>()) {
    sl.registerLazySingleton<WatchDashboardSummaryUseCase>(
      () => WatchDashboardSummaryUseCase(sl<DashboardRepository>()),
    );
  }
  if (!sl.isRegistered<DashboardCubit>()) {
    sl.registerFactory(
      () =>
          DashboardCubit(sl<WatchDashboardSummaryUseCase>(), sl<DateService>()),
    );
  }
  if (!sl.isRegistered<WatchCustomerTransactionsUseCase>()) {
    sl.registerLazySingleton<WatchCustomerTransactionsUseCase>(
      () => WatchCustomerTransactionsUseCase(sl<TransactionRepository>()),
    );
  }
  if (!sl.isRegistered<CustomerTransactionsCubit>()) {
    sl.registerFactory(
      () => CustomerTransactionsCubit(
        sl<WatchCustomerTransactionsUseCase>(),
        sl<SoftDeleteTransactionUseCase>(),
      ),
    );
  }
  if (!sl.isRegistered<TransactionFormCubit>()) {
    sl.registerFactory(
      () => TransactionFormCubit(
        sl<WatchCustomersUseCase>(),
        sl<GetTransactionByIdUseCase>(),
        sl<CreateTransactionUseCase>(),
        sl<EditTransactionUseCase>(),
      ),
    );
  }
  if (!sl.isRegistered<GetTransactionByIdUseCase>()) {
    sl.registerLazySingleton<GetTransactionByIdUseCase>(
      () => GetTransactionByIdUseCase(sl<TransactionRepository>()),
    );
  }
  if (!sl.isRegistered<CreateTransactionUseCase>()) {
    sl.registerLazySingleton<CreateTransactionUseCase>(
      () => CreateTransactionUseCase(sl<TransactionRepository>()),
    );
  }
  if (!sl.isRegistered<EditTransactionUseCase>()) {
    sl.registerLazySingleton<EditTransactionUseCase>(
      () => EditTransactionUseCase(sl<TransactionRepository>()),
    );
  }
  if (!sl.isRegistered<SoftDeleteTransactionUseCase>()) {
    sl.registerLazySingleton<SoftDeleteTransactionUseCase>(
      () => SoftDeleteTransactionUseCase(sl<TransactionRepository>()),
    );
  }
  if (!sl.isRegistered<WatchCustomersUseCase>()) {
    sl.registerLazySingleton<WatchCustomersUseCase>(
      () => WatchCustomersUseCase(sl<CustomerRepository>()),
    );
  }
  if (!sl.isRegistered<WatchCustomerDetailsUseCase>()) {
    sl.registerLazySingleton<WatchCustomerDetailsUseCase>(
      () => WatchCustomerDetailsUseCase(sl<CustomerRepository>()),
    );
  }
  if (!sl.isRegistered<CreateCustomerUseCase>()) {
    sl.registerLazySingleton<CreateCustomerUseCase>(
      () => CreateCustomerUseCase(sl<CustomerRepository>()),
    );
  }
  if (!sl.isRegistered<UpdateCustomerUseCase>()) {
    sl.registerLazySingleton<UpdateCustomerUseCase>(
      () => UpdateCustomerUseCase(sl<CustomerRepository>()),
    );
  }
  if (!sl.isRegistered<SoftDeleteCustomerUseCase>()) {
    sl.registerLazySingleton<SoftDeleteCustomerUseCase>(
      () => SoftDeleteCustomerUseCase(sl<CustomerRepository>()),
    );
  }
  if (!sl.isRegistered<PickContactUseCase>()) {
    sl.registerLazySingleton<PickContactUseCase>(
      () => PickContactUseCase(sl<CustomerRepository>()),
    );
  }
  if (!sl.isRegistered<CustomersListCubit>()) {
    sl.registerFactory(
      () => CustomersListCubit(
        sl<WatchCustomersUseCase>(),
        sl<PickContactUseCase>(),
      ),
    );
  }
  if (!sl.isRegistered<CustomerFormCubit>()) {
    sl.registerFactory(
      () => CustomerFormCubit(
        sl<CreateCustomerUseCase>(),
        sl<UpdateCustomerUseCase>(),
        sl<WatchCustomerDetailsUseCase>(),
        sl<PickContactUseCase>(),
      ),
    );
  }
  if (!sl.isRegistered<CustomerDetailsCubit>()) {
    sl.registerFactory(
      () => CustomerDetailsCubit(
        sl<WatchCustomerDetailsUseCase>(),
        sl<SoftDeleteCustomerUseCase>(),
      ),
    );
  }
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
  if (!sl.isRegistered<ChangeThemeUseCase>()) {
    sl.registerLazySingleton<ChangeThemeUseCase>(
      () => ChangeThemeUseCase(sl<SettingsRepository>()),
    );
  }
  if (!sl.isRegistered<SettingsCubit>()) {
    sl.registerLazySingleton<SettingsCubit>(
      () => SettingsCubit(
        sl<GetSettingsUseCase>(),
        sl<ChangeLanguageUseCase>(),
        sl<ChangeThemeUseCase>(),
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
  await sl<AppLockCubit>().initialize();
  await sl<AuthSessionCubit>().initialize();
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
