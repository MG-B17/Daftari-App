import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/usecases/get_settings_usecase.dart';
import '../../features/settings/domain/usecases/change_language_usecase.dart';
import '../../features/settings/domain/usecases/change_theme_usecase.dart';
import '../database/app_database.dart';
import '../errors/app_exception.dart';
import '../errors/error_handler.dart';
import '../routing/app_router.dart';
import '../services/app_logger.dart';
import '../services/connectivity_service.dart';
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
