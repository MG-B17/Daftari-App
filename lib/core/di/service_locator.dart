import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/usecases/get_settings_usecase.dart';
import '../../features/settings/domain/usecases/change_language_usecase.dart';
import '../../features/settings/domain/usecases/change_theme_usecase.dart';
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
  if (!sl.isRegistered<AppDatabase>()) {
    sl.registerLazySingleton<AppDatabase>(
      AppDatabase.new,
      dispose: (database) => database.close(),
    );
  }
  if (!sl.isRegistered<CustomerDao>()) {
    sl.registerLazySingleton<CustomerDao>(() => sl<AppDatabase>().customerDao);
  }
  if (!sl.isRegistered<TransactionDao>()) {
    sl.registerLazySingleton<TransactionDao>(
      () => sl<AppDatabase>().transactionDao,
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
  if (!sl.isRegistered<GoRouter>()) {
    sl.registerLazySingleton<GoRouter>(
      () => AppRouter.create(
        localStorage: sl<LocalStorageService>(),
        createOnboardingCubit: () => sl<OnboardingCubit>(),
      ),
      dispose: (router) => router.dispose(),
    );
  }
}
