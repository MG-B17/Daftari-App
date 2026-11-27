import 'dart:io';

import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/di/di.dart' as core_di;
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/core/services/connectivity/connectivity_service.dart';
import 'package:daftariapp/core/services/date/date_service.dart';
import 'package:daftariapp/core/services/loacl_storage/local_storage_service.dart';
import 'package:daftariapp/core/services/session_commit_gate/session_commit_gate.dart';
import 'package:daftariapp/core/theme/theme_controller/theme_switcher_cubit.dart';
import 'package:daftariapp/features/auth/di/auth_di.dart';
import 'package:daftariapp/features/auth/forgot_password/domain/repositories/forgot_password_repository.dart';
import 'package:daftariapp/features/auth/forgot_password/domain/usecases/send_password_reset_usecase.dart';
import 'package:daftariapp/features/auth/forgot_password/presentation/cubit/forgot_password_cubit.dart';
import 'package:daftariapp/features/auth/login/domain/repositories/login_repository.dart';
import 'package:daftariapp/features/auth/login/domain/usecases/sign_in_usecase.dart';
import 'package:daftariapp/features/auth/login/presentation/cubit/login_cubit.dart';
import 'package:daftariapp/features/auth/session/data/services/auth_error_mapper.dart';
import 'package:daftariapp/features/auth/session/data/services/ledger_owner_storage.dart';
import 'package:daftariapp/features/auth/session/data/services/supabase_auth_service.dart';
import 'package:daftariapp/features/auth/session/data/services/supabase_bootstrap.dart';
import 'package:daftariapp/features/auth/session/domain/repositories/auth_session_coordinator.dart';
import 'package:daftariapp/features/auth/session/domain/repositories/auth_session_repository.dart';
import 'package:daftariapp/features/auth/session/domain/usecases/confirm_ledger_link_usecase.dart';
import 'package:daftariapp/features/auth/session/domain/usecases/sign_out_usecase.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'package:daftariapp/features/auth/sign_up/domain/repositories/sign_up_repository.dart';
import 'package:daftariapp/features/auth/sign_up/domain/usecases/sign_up_usecase.dart';
import 'package:daftariapp/features/auth/sign_up/presentation/cubit/sign_up_cubit.dart';
import 'package:daftariapp/features/auth/update_password/domain/repositories/update_password_repository.dart';
import 'package:daftariapp/features/auth/update_password/domain/usecases/update_password_usecase.dart';
import 'package:daftariapp/features/auth/update_password/presentation/cubit/update_password_cubit.dart';
import 'package:daftariapp/features/auth/verify_email/domain/repositories/verify_email_repository.dart';
import 'package:daftariapp/features/auth/verify_email/domain/usecases/check_email_verified_usecase.dart';
import 'package:daftariapp/features/auth/verify_email/domain/usecases/resend_verification_email_usecase.dart';
import 'package:daftariapp/features/auth/verify_email/presentation/cubit/verify_email_cubit.dart';
import 'package:daftariapp/features/backup/data/services/android_backup_platform_bridge.dart';
import 'package:daftariapp/features/backup/data/services/backup_device_storage.dart';
import 'package:daftariapp/features/backup/di/backup_di.dart';
import 'package:daftariapp/features/backup/domain/repositories/backup_cloud_publisher.dart';
import 'package:daftariapp/features/backup/domain/repositories/backup_local_store.dart';
import 'package:daftariapp/features/backup/domain/repositories/backup_run_lock.dart';
import 'package:daftariapp/features/backup/domain/repositories/backup_scheduler.dart';
import 'package:daftariapp/features/backup/domain/usecases/run_backup_usecase.dart';
import 'package:daftariapp/features/backup/domain/usecases/update_backup_schedule_usecase.dart';
import 'package:daftariapp/features/backup/presentation/cubit/backup_cubit.dart';
import 'package:daftariapp/features/restore/data/services/restore_transfer_storage.dart';
import 'package:daftariapp/features/restore/di/restore_di.dart';
import 'package:daftariapp/features/restore/domain/repositories/restore_cloud_service.dart';
import 'package:daftariapp/features/restore/domain/repositories/restore_local_store.dart';
import 'package:daftariapp/features/restore/domain/repositories/restore_repository.dart';
import 'package:daftariapp/features/restore/presentation/cubit/restore_cubit.dart';
import 'package:daftariapp/features/customers/di/customers_di.dart';
import 'package:daftariapp/features/customers/domain/repositories/customer_repository.dart';
import 'package:daftariapp/features/customers/domain/usecases/create_customer_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/pick_contact_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/soft_delete_customer_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/update_customer_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/watch_customer_details_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/watch_customers_usecase.dart';
import 'package:daftariapp/features/customers/presentation/cubit/customer_details_cubit.dart';
import 'package:daftariapp/features/customers/presentation/cubit/customer_form_cubit.dart';
import 'package:daftariapp/features/customers/presentation/cubit/customers_list_cubit.dart';
import 'package:daftariapp/features/dashboard/di/dashboard_di.dart';
import 'package:daftariapp/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:daftariapp/features/dashboard/domain/usecases/watch_dashboard_summary_usecase.dart';
import 'package:daftariapp/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:daftariapp/features/settings/di/settings_di.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/settings/domain/repositories/settings_repository.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/core/services/image_exporter/widget_image_exporter.dart';
import 'package:daftariapp/features/statements/data/services/statement_share_service.dart';
import 'package:daftariapp/features/statements/di/statements_di.dart';
import 'package:daftariapp/features/statements/domain/entities/statement_date_range.dart';
import 'package:daftariapp/features/statements/domain/repositories/statement_repository.dart';
import 'package:daftariapp/features/statements/domain/usecases/get_customer_statement_usecase.dart';
import 'package:daftariapp/features/statements/presentation/cubit/statement_cubit.dart';
import 'package:daftariapp/features/statements/presentation/services/statement_image_renderer.dart';
import 'package:daftariapp/features/transactions/di/transactions_di.dart';
import 'package:daftariapp/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:daftariapp/features/transactions/domain/usecases/create_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/edit_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/get_transaction_by_id_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/soft_delete_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/watch_customer_transactions_usecase.dart';
import 'package:daftariapp/features/transactions/presentation/cubit/customer_transactions_cubit.dart';
import 'package:daftariapp/features/transactions/presentation/cubit/transaction_form_cubit.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:daftariapp/features/security/data/services/secure_storage_service.dart';
import 'package:daftariapp/features/security/data/services/biometric_auth_service.dart';
import 'package:daftariapp/features/security/di/security_di.dart';
import 'package:daftariapp/features/security/domain/repositories/security_repository.dart';
import 'package:daftariapp/features/security/presentation/cubit/app_lock_cubit.dart';
import 'package:daftariapp/features/search/domain/repositories/search_repository.dart';
import 'package:daftariapp/features/search/domain/usecases/watch_search_customers_usecase.dart';
import 'package:daftariapp/features/search/presentation/cubit/search_cubit.dart';
import 'package:daftariapp/features/layout/di/layout_di.dart';
import 'package:daftariapp/features/onboarding/di/onboarding_di.dart';
import 'package:daftariapp/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:daftariapp/features/splash/di/splash_di.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => sl.reset());

  test(
    'simultaneous/repeated DI setup preserves every registered instance',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      sl.registerSingleton<AppDatabase>(database);
      await Future.wait([configureDependencies(), configureDependencies()]);
      final instances = <Object>[
        sl<SharedPreferences>(),
        sl<LocalStorageService>(),
        sl<ConnectivityService>(),
        sl<DateService>(),
        sl<AppLogger>(),
        sl<ErrorHandler>(),
        sl<GoRouter>(),
        sl<SettingsCubit>(),
        sl<ThemeSwitcherCubit>(),
        sl<SettingsRepository>(),
        sl<GetSettingsUseCase>(),
        sl<ChangeLanguageUseCase>(),
        sl<TransactionRepository>(),
        sl<CreateTransactionUseCase>(),
        sl<EditTransactionUseCase>(),
        sl<GetTransactionByIdUseCase>(),
        sl<SoftDeleteTransactionUseCase>(),
        sl<WatchCustomerTransactionsUseCase>(),
        sl<CustomerRepository>(),
        sl<WatchCustomersUseCase>(),
        sl<WatchCustomerDetailsUseCase>(),
        sl<CreateCustomerUseCase>(),
        sl<UpdateCustomerUseCase>(),
        sl<SoftDeleteCustomerUseCase>(),
        sl<PickContactUseCase>(),
        sl<DashboardRepository>(),
        sl<WatchDashboardSummaryUseCase>(),
        sl<SearchRepository>(),
        sl<WatchSearchCustomersUseCase>(),
        sl<StatementRepository>(),
        sl<GetCustomerStatementUseCase>(),
        sl<StatementShareService>(),
        sl<FlutterSecureStorage>(),
        sl<LocalAuthentication>(),
        sl<SecureStorageService>(),
        sl<BiometricAuthService>(),
        sl<SecurityRepository>(),
        sl<BackupDao>(),
        sl<BackupDeviceStorage>(),
        sl<AndroidBackupPlatformBridge>(),
        sl<BackupRunLock>(),
        sl<BackupScheduler>(),
        sl<SessionCommitGate>(),
        sl<BackupLocalStore>(),
        sl<BackupCloudPublisher>(),
        sl<RunBackupUseCase>(),
        sl<UpdateBackupScheduleUseCase>(),
        sl<BackupCubit>(),
        sl<RestoreTransferStorage>(),
        sl<RestoreLocalStore>(),
        sl<RestoreCloudService>(),
        sl<RestoreRepository>(),
      ];
      await configureDependencies();
      final repeated = <Object>[
        sl<SharedPreferences>(),
        sl<LocalStorageService>(),
        sl<ConnectivityService>(),
        sl<DateService>(),
        sl<AppLogger>(),
        sl<ErrorHandler>(),
        sl<GoRouter>(),
        sl<SettingsCubit>(),
        sl<ThemeSwitcherCubit>(),
        sl<SettingsRepository>(),
        sl<GetSettingsUseCase>(),
        sl<ChangeLanguageUseCase>(),
        sl<TransactionRepository>(),
        sl<CreateTransactionUseCase>(),
        sl<EditTransactionUseCase>(),
        sl<GetTransactionByIdUseCase>(),
        sl<SoftDeleteTransactionUseCase>(),
        sl<WatchCustomerTransactionsUseCase>(),
        sl<CustomerRepository>(),
        sl<WatchCustomersUseCase>(),
        sl<WatchCustomerDetailsUseCase>(),
        sl<CreateCustomerUseCase>(),
        sl<UpdateCustomerUseCase>(),
        sl<SoftDeleteCustomerUseCase>(),
        sl<PickContactUseCase>(),
        sl<DashboardRepository>(),
        sl<WatchDashboardSummaryUseCase>(),
        sl<SearchRepository>(),
        sl<WatchSearchCustomersUseCase>(),
        sl<StatementRepository>(),
        sl<GetCustomerStatementUseCase>(),
        sl<StatementShareService>(),
        sl<FlutterSecureStorage>(),
        sl<LocalAuthentication>(),
        sl<SecureStorageService>(),
        sl<BiometricAuthService>(),
        sl<SecurityRepository>(),
        sl<BackupDao>(),
        sl<BackupDeviceStorage>(),
        sl<AndroidBackupPlatformBridge>(),
        sl<BackupRunLock>(),
        sl<BackupScheduler>(),
        sl<SessionCommitGate>(),
        sl<BackupLocalStore>(),
        sl<BackupCloudPublisher>(),
        sl<RunBackupUseCase>(),
        sl<UpdateBackupScheduleUseCase>(),
        sl<BackupCubit>(),
        sl<RestoreTransferStorage>(),
        sl<RestoreLocalStore>(),
        sl<RestoreCloudService>(),
        sl<RestoreRepository>(),
      ];
      for (var i = 0; i < instances.length; i++) {
        expect(repeated[i], same(instances[i]));
      }
      expect(sl<DateService>(), isA<SystemDateService>());
      expect(
        sl<FlutterSecureStorage>().aOptions.toMap()['resetOnError'],
        'false',
      );
      // Debug setup and handling do not access Firebase without initialization.
      await sl<ErrorHandler>().handle(Exception('private details'));
    },
  );

  test('bootstrap preserves injected services and preferences', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('localeCode', 'en');
    final logger = AppLogger(output: (_) {});
    sl.registerSingleton<SharedPreferences>(preferences);
    sl.registerSingleton<AppLogger>(logger);
    await configureDependencies();
    expect(sl<AppLogger>(), same(logger));
    expect(sl<LocalStorageService>().localeCode, 'en');
  });

  test('onboarding cubit is factory scoped', () async {
    await configureDependencies();
    final first = sl<OnboardingCubit>();
    final second = sl<OnboardingCubit>();
    expect(first, isNot(same(second)));
    first.nextPage();
    expect(second.state.pageIndex, 0);
    await first.close();
    await second.close();
  });

  test('statement cubit is factory scoped after repeated setup', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    sl.registerSingleton<AppDatabase>(database);
    await Future.wait([configureDependencies(), configureDependencies()]);
    final first = sl<StatementCubit>();
    await configureDependencies();
    final second = sl<StatementCubit>();
    addTearDown(first.close);
    addTearDown(second.close);
    expect(first, isNot(same(second)));
    expect(first.state, const StatementState());
    expect(second.state, const StatementState());
    await first.setRange(StatementDateRange.thisMonth);
    expect(second.state.range, StatementDateRange.all);
  });

  test(
    'customers DI registers lazy singletons and factory cubits via core di',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      sl.registerSingleton<AppDatabase>(database);
      await core_di.configureDependencies();

      final repository = sl<CustomerRepository>();
      final watchAll = sl<WatchCustomersUseCase>();
      final watchDetails = sl<WatchCustomerDetailsUseCase>();
      final create = sl<CreateCustomerUseCase>();
      final update = sl<UpdateCustomerUseCase>();
      final softDelete = sl<SoftDeleteCustomerUseCase>();
      final pickContact = sl<PickContactUseCase>();

      registerCustomersDependencies(sl);
      expect(sl<CustomerRepository>(), same(repository));
      expect(sl<WatchCustomersUseCase>(), same(watchAll));
      expect(sl<WatchCustomerDetailsUseCase>(), same(watchDetails));
      expect(sl<CreateCustomerUseCase>(), same(create));
      expect(sl<UpdateCustomerUseCase>(), same(update));
      expect(sl<SoftDeleteCustomerUseCase>(), same(softDelete));
      expect(sl<PickContactUseCase>(), same(pickContact));

      final firstList = sl<CustomersListCubit>();
      final secondList = sl<CustomersListCubit>();
      final firstForm = sl<CustomerFormCubit>();
      final secondForm = sl<CustomerFormCubit>();
      final firstDetails = sl<CustomerDetailsCubit>();
      final secondDetails = sl<CustomerDetailsCubit>();
      addTearDown(firstList.close);
      addTearDown(secondList.close);
      addTearDown(firstForm.close);
      addTearDown(secondForm.close);
      addTearDown(firstDetails.close);
      addTearDown(secondDetails.close);
      expect(firstList, isNot(same(secondList)));
      expect(firstForm, isNot(same(secondForm)));
      expect(firstDetails, isNot(same(secondDetails)));
    },
  );

  test(
    'dashboard DI registers lazy singletons and factory cubit via core di',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      sl.registerSingleton<AppDatabase>(database);
      await core_di.configureDependencies();

      final repository = sl<DashboardRepository>();
      final useCase = sl<WatchDashboardSummaryUseCase>();
      registerDashboardDependencies(sl);
      expect(sl<DashboardRepository>(), same(repository));
      expect(sl<WatchDashboardSummaryUseCase>(), same(useCase));

      final first = sl<DashboardCubit>();
      final second = sl<DashboardCubit>();
      addTearDown(first.close);
      addTearDown(second.close);
      expect(first, isNot(same(second)));
      expect(first.state, const DashboardState());
      expect(second.state, const DashboardState());
    },
  );

  test(
    'database and DAOs are lazy singletons sharing one connection',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      sl.registerSingleton<AppDatabase>(database);

      await configureDependencies();

      expect(sl<AppDatabase>(), same(database));
      expect(sl<CustomerDao>(), same(database.customerDao));
      expect(sl<TransactionDao>(), same(database.transactionDao));
      expect(sl<BackupDao>(), same(database.backupDao));
    },
  );

  test(
    'search cubit is factory scoped and exposed through core di entry point',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      sl.registerSingleton<AppDatabase>(database);
      await core_di.configureDependencies();

      expect(core_di.sl, same(sl));
      final first = sl<SearchCubit>();
      final second = sl<SearchCubit>();
      addTearDown(first.close);
      addTearDown(second.close);

      expect(first, isNot(same(second)));
      first.setQuery('010');
      expect(second.state.query, isEmpty);
    },
  );

  test(
    'transactions DI registers lazy singletons and factory cubits via core di',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      sl.registerSingleton<AppDatabase>(database);
      await core_di.configureDependencies();

      final repository = sl<TransactionRepository>();
      final watch = sl<WatchCustomerTransactionsUseCase>();
      final getById = sl<GetTransactionByIdUseCase>();
      final create = sl<CreateTransactionUseCase>();
      final edit = sl<EditTransactionUseCase>();
      final softDelete = sl<SoftDeleteTransactionUseCase>();

      registerTransactionsDependencies(sl);
      expect(sl<TransactionRepository>(), same(repository));
      expect(sl<WatchCustomerTransactionsUseCase>(), same(watch));
      expect(sl<GetTransactionByIdUseCase>(), same(getById));
      expect(sl<CreateTransactionUseCase>(), same(create));
      expect(sl<EditTransactionUseCase>(), same(edit));
      expect(sl<SoftDeleteTransactionUseCase>(), same(softDelete));

      final firstForm = sl<TransactionFormCubit>();
      final secondForm = sl<TransactionFormCubit>();
      final firstHistory = sl<CustomerTransactionsCubit>();
      final secondHistory = sl<CustomerTransactionsCubit>();
      addTearDown(firstForm.close);
      addTearDown(secondForm.close);
      addTearDown(firstHistory.close);
      addTearDown(secondHistory.close);
      expect(firstForm, isNot(same(secondForm)));
      expect(firstHistory, isNot(same(secondHistory)));
    },
  );

  test(
    'statements DI registers lazy singletons and factory cubit via core di',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      sl.registerSingleton<AppDatabase>(database);
      await core_di.configureDependencies();

      final exporter = sl<WidgetImageExporter>();
      final repository = sl<StatementRepository>();
      final useCase = sl<GetCustomerStatementUseCase>();
      final renderer = sl<StatementImageRenderer>();
      final shareService = sl<StatementShareService>();

      registerStatementsDependencies(sl);
      expect(sl<WidgetImageExporter>(), same(exporter));
      expect(sl<StatementRepository>(), same(repository));
      expect(sl<GetCustomerStatementUseCase>(), same(useCase));
      expect(sl<StatementImageRenderer>(), same(renderer));
      expect(sl<StatementShareService>(), same(shareService));

      final first = sl<StatementCubit>();
      final second = sl<StatementCubit>();
      addTearDown(first.close);
      addTearDown(second.close);
      expect(first, isNot(same(second)));
      expect(first.state, const StatementState());
      expect(second.state, const StatementState());
    },
  );

  test(
    'auth DI registers lazy singletons and factory form cubits via core di',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      sl.registerSingleton<AppDatabase>(database);
      await core_di.configureDependencies();

      final bootstrap = sl<SupabaseBootstrap>();
      final ownerStorage = sl<LedgerOwnerStorage>();
      final authService = sl<AuthService>();
      final errorMapper = sl<AuthErrorMapper>();
      final sessionRepository = sl<AuthSessionRepository>();
      final signOut = sl<SignOutUseCase>();
      final confirmLink = sl<ConfirmLedgerLinkUseCase>();
      final sessionCubit = sl<AuthSessionCubit>();
      final coordinator = sl<AuthSessionCoordinator>();
      final loginRepository = sl<LoginRepository>();
      final signIn = sl<SignInUseCase>();
      final signUpRepository = sl<SignUpRepository>();
      final signUp = sl<SignUpUseCase>();
      final forgotRepository = sl<ForgotPasswordRepository>();
      final sendReset = sl<SendPasswordResetUseCase>();
      final verifyRepository = sl<VerifyEmailRepository>();
      final resend = sl<ResendVerificationEmailUseCase>();
      final checkVerified = sl<CheckEmailVerifiedUseCase>();
      final updateRepository = sl<UpdatePasswordRepository>();
      final updatePassword = sl<UpdatePasswordUseCase>();

      registerAuthDependencies(sl);
      expect(sl<SupabaseBootstrap>(), same(bootstrap));
      expect(sl<LedgerOwnerStorage>(), same(ownerStorage));
      expect(sl<AuthService>(), same(authService));
      expect(sl<AuthErrorMapper>(), same(errorMapper));
      expect(sl<AuthSessionRepository>(), same(sessionRepository));
      expect(sl<SignOutUseCase>(), same(signOut));
      expect(sl<ConfirmLedgerLinkUseCase>(), same(confirmLink));
      expect(sl<AuthSessionCubit>(), same(sessionCubit));
      expect(sl<AuthSessionCoordinator>(), same(coordinator));
      expect(coordinator, same(sessionCubit));
      expect(sl<LoginRepository>(), same(loginRepository));
      expect(sl<SignInUseCase>(), same(signIn));
      expect(sl<SignUpRepository>(), same(signUpRepository));
      expect(sl<SignUpUseCase>(), same(signUp));
      expect(sl<ForgotPasswordRepository>(), same(forgotRepository));
      expect(sl<SendPasswordResetUseCase>(), same(sendReset));
      expect(sl<VerifyEmailRepository>(), same(verifyRepository));
      expect(sl<ResendVerificationEmailUseCase>(), same(resend));
      expect(sl<CheckEmailVerifiedUseCase>(), same(checkVerified));
      expect(sl<UpdatePasswordRepository>(), same(updateRepository));
      expect(sl<UpdatePasswordUseCase>(), same(updatePassword));

      final firstLogin = sl<LoginCubit>();
      final secondLogin = sl<LoginCubit>();
      final firstSignUp = sl<SignUpCubit>();
      final secondSignUp = sl<SignUpCubit>();
      final firstForgot = sl<ForgotPasswordCubit>();
      final secondForgot = sl<ForgotPasswordCubit>();
      final firstVerify = sl<VerifyEmailCubit>();
      final secondVerify = sl<VerifyEmailCubit>();
      final firstUpdate = sl<UpdatePasswordCubit>();
      final secondUpdate = sl<UpdatePasswordCubit>();
      addTearDown(firstLogin.close);
      addTearDown(secondLogin.close);
      addTearDown(firstSignUp.close);
      addTearDown(secondSignUp.close);
      addTearDown(firstForgot.close);
      addTearDown(secondForgot.close);
      addTearDown(firstVerify.close);
      addTearDown(secondVerify.close);
      addTearDown(firstUpdate.close);
      addTearDown(secondUpdate.close);
      expect(firstLogin, isNot(same(secondLogin)));
      expect(firstSignUp, isNot(same(secondSignUp)));
      expect(firstForgot, isNot(same(secondForgot)));
      expect(firstVerify, isNot(same(secondVerify)));
      expect(firstUpdate, isNot(same(secondUpdate)));
    },
  );

  test('security DI registers lazy singletons via core di', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    sl.registerSingleton<AppDatabase>(database);
    await core_di.configureDependencies();

    final localAuth = sl<LocalAuthentication>();
    final secureStorage = sl<SecureStorageService>();
    final biometricAuth = sl<BiometricAuthService>();
    final repository = sl<SecurityRepository>();
    final appLock = sl<AppLockCubit>();

    registerSecurityDependencies(sl);
    expect(sl<LocalAuthentication>(), same(localAuth));
    expect(sl<SecureStorageService>(), same(secureStorage));
    expect(sl<BiometricAuthService>(), same(biometricAuth));
    expect(sl<SecurityRepository>(), same(repository));
    expect(sl<AppLockCubit>(), same(appLock));
    expect(appLock.state.initialized, isTrue);
  });

  test('backup DI registers lazy singletons via core di', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    sl.registerSingleton<AppDatabase>(database);
    await core_di.configureDependencies();

    final platformBridge = sl<AndroidBackupPlatformBridge>();
    final runLock = sl<BackupRunLock>();
    final scheduler = sl<BackupScheduler>();
    final deviceStorage = sl<BackupDeviceStorage>();
    final localStore = sl<BackupLocalStore>();
    final cloudPublisher = sl<BackupCloudPublisher>();
    final runBackup = sl<RunBackupUseCase>();
    final updateSchedule = sl<UpdateBackupScheduleUseCase>();
    final backupCubit = sl<BackupCubit>();

    registerBackupDependencies(sl);
    expect(sl<AndroidBackupPlatformBridge>(), same(platformBridge));
    expect(sl<BackupRunLock>(), same(runLock));
    expect(sl<BackupScheduler>(), same(scheduler));
    expect(runLock, same(platformBridge));
    expect(scheduler, same(platformBridge));
    expect(sl<BackupDeviceStorage>(), same(deviceStorage));
    expect(sl<BackupLocalStore>(), same(localStore));
    expect(sl<BackupCloudPublisher>(), same(cloudPublisher));
    expect(sl<RunBackupUseCase>(), same(runBackup));
    expect(sl<UpdateBackupScheduleUseCase>(), same(updateSchedule));
    expect(sl<BackupCubit>(), same(backupCubit));
  });

  test(
    'restore DI registers lazy singletons and factory cubit via core di',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      sl.registerSingleton<AppDatabase>(database);
      await core_di.configureDependencies();

      final transferStorage = sl<RestoreTransferStorage>();
      final localStore = sl<RestoreLocalStore>();
      final cloudService = sl<RestoreCloudService>();
      final repository = sl<RestoreRepository>();
      final backupLocalStore = sl<BackupLocalStore>();

      registerRestoreDependencies(sl);
      expect(sl<RestoreTransferStorage>(), same(transferStorage));
      expect(sl<RestoreLocalStore>(), same(localStore));
      expect(sl<RestoreCloudService>(), same(cloudService));
      expect(sl<RestoreRepository>(), same(repository));
      expect(sl<BackupLocalStore>(), same(backupLocalStore));

      final first = sl<RestoreCubit>();
      final second = sl<RestoreCubit>();
      addTearDown(first.close);
      addTearDown(second.close);
      expect(first, isNot(same(second)));
    },
  );

  test('settings DI registers lazy singletons via core di', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    sl.registerSingleton<AppDatabase>(database);
    await core_di.configureDependencies();

    final repository = sl<SettingsRepository>();
    final getSettings = sl<GetSettingsUseCase>();
    final changeLanguage = sl<ChangeLanguageUseCase>();
    final settingsCubit = sl<SettingsCubit>();
    final themeSwitcher = sl<ThemeSwitcherCubit>();

    registerSettingsDependencies(sl);
    expect(sl<SettingsRepository>(), same(repository));
    expect(sl<GetSettingsUseCase>(), same(getSettings));
    expect(sl<ChangeLanguageUseCase>(), same(changeLanguage));
    expect(sl<SettingsCubit>(), same(settingsCubit));
    expect(sl<ThemeSwitcherCubit>(), same(themeSwitcher));

    await sl.reset();
    expect(settingsCubit.isClosed, isTrue);
  });

  test('onboarding DI registers factory cubit via core di', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    sl.registerSingleton<AppDatabase>(database);
    await core_di.configureDependencies();

    registerOnboardingDependencies(sl);
    final first = sl<OnboardingCubit>();
    final second = sl<OnboardingCubit>();
    addTearDown(first.close);
    addTearDown(second.close);
    expect(first, isNot(same(second)));
    first.nextPage();
    expect(second.state.pageIndex, 0);
  });

  test(
    'layout DI entry point is wired via core di with zero registrations',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      sl.registerSingleton<AppDatabase>(database);
      await core_di.configureDependencies();

      expect(() => registerLayoutDependencies(sl), returnsNormally);
    },
  );

  test(
    'splash DI entry point is wired via core di with zero registrations',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      sl.registerSingleton<AppDatabase>(database);
      await core_di.configureDependencies();

      expect(() => registerSplashDependencies(sl), returnsNormally);
    },
  );

  test('every feature directory has a DI file wired in core di', () {
    final featuresDir = Directory('lib/features');
    final featureNames =
        featuresDir
            .listSync()
            .whereType<Directory>()
            .map((dir) => dir.path.split(Platform.pathSeparator).last)
            .toList()
          ..sort();
    final coreDiSource = File('lib/core/di/di.dart').readAsStringSync();
    for (final feature in featureNames) {
      final diFile = File('lib/features/$feature/di/${feature}_di.dart');
      expect(
        diFile.existsSync(),
        isTrue,
        reason: 'Missing DI file for feature "$feature"',
      );
      expect(
        coreDiSource,
        contains('../../features/$feature/di/${feature}_di.dart'),
        reason: 'Core DI does not wire feature "$feature"',
      );
    }
  });
}
