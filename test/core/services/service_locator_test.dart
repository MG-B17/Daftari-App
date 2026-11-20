import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/connectivity_service.dart';
import 'package:daftariapp/core/services/date_service.dart';
import 'package:daftariapp/core/services/local_storage_service.dart';
import 'package:daftariapp/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:daftariapp/features/dashboard/domain/usecases/watch_dashboard_summary_usecase.dart';
import 'package:daftariapp/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/settings/domain/repositories/settings_repository.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_theme_usecase.dart';
import 'package:daftariapp/features/statements/data/services/statement_share_service.dart';
import 'package:daftariapp/features/statements/domain/entities/statement_date_range.dart';
import 'package:daftariapp/features/statements/domain/repositories/statement_repository.dart';
import 'package:daftariapp/features/statements/domain/usecases/get_customer_statement_usecase.dart';
import 'package:daftariapp/features/statements/presentation/cubit/statement_cubit.dart';
import 'package:daftariapp/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:daftariapp/features/transactions/domain/usecases/create_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/edit_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/get_transaction_by_id_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/soft_delete_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/watch_customer_transactions_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:daftariapp/features/security/data/services/secure_storage_service.dart';
import 'package:daftariapp/features/security/data/services/biometric_auth_service.dart';
import 'package:daftariapp/features/security/domain/repositories/security_repository.dart';
import 'package:daftariapp/features/onboarding/presentation/cubit/onboarding_cubit.dart';

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
        sl<SettingsRepository>(),
        sl<GetSettingsUseCase>(),
        sl<ChangeLanguageUseCase>(),
        sl<ChangeThemeUseCase>(),
        sl<TransactionRepository>(),
        sl<CreateTransactionUseCase>(),
        sl<EditTransactionUseCase>(),
        sl<GetTransactionByIdUseCase>(),
        sl<SoftDeleteTransactionUseCase>(),
        sl<WatchCustomerTransactionsUseCase>(),
        sl<DashboardRepository>(),
        sl<WatchDashboardSummaryUseCase>(),
        sl<StatementRepository>(),
        sl<GetCustomerStatementUseCase>(),
        sl<StatementShareService>(),
        sl<FlutterSecureStorage>(),
        sl<LocalAuthentication>(),
        sl<SecureStorageService>(),
        sl<BiometricAuthService>(),
        sl<SecurityRepository>(),
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
        sl<SettingsRepository>(),
        sl<GetSettingsUseCase>(),
        sl<ChangeLanguageUseCase>(),
        sl<ChangeThemeUseCase>(),
        sl<TransactionRepository>(),
        sl<CreateTransactionUseCase>(),
        sl<EditTransactionUseCase>(),
        sl<GetTransactionByIdUseCase>(),
        sl<SoftDeleteTransactionUseCase>(),
        sl<WatchCustomerTransactionsUseCase>(),
        sl<DashboardRepository>(),
        sl<WatchDashboardSummaryUseCase>(),
        sl<StatementRepository>(),
        sl<GetCustomerStatementUseCase>(),
        sl<StatementShareService>(),
        sl<FlutterSecureStorage>(),
        sl<LocalAuthentication>(),
        sl<SecureStorageService>(),
        sl<BiometricAuthService>(),
        sl<SecurityRepository>(),
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
    'dashboard cubit is factory scoped and starts without a watch',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      sl.registerSingleton<AppDatabase>(database);
      await configureDependencies();
      final first = sl<DashboardCubit>();
      final second = sl<DashboardCubit>();
      expect(first, isNot(same(second)));
      expect(first.state, const DashboardState());
      expect(second.state, const DashboardState());
      await first.close();
      await second.close();
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
    },
  );
}
