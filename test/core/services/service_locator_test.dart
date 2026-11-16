import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/connectivity_service.dart';
import 'package:daftariapp/core/services/local_storage_service.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/settings/domain/repositories/settings_repository.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_theme_usecase.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daftariapp/features/onboarding/presentation/cubit/onboarding_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => sl.reset());

  test(
    'simultaneous/repeated DI setup preserves every registered instance',
    () async {
      await Future.wait([configureDependencies(), configureDependencies()]);
      final instances = <Object>[
        sl<SharedPreferences>(),
        sl<LocalStorageService>(),
        sl<ConnectivityService>(),
        sl<AppLogger>(),
        sl<ErrorHandler>(),
        sl<GoRouter>(),
        sl<SettingsCubit>(),
        sl<SettingsRepository>(),
        sl<GetSettingsUseCase>(),
        sl<ChangeLanguageUseCase>(),
        sl<ChangeThemeUseCase>(),
      ];
      await configureDependencies();
      final repeated = <Object>[
        sl<SharedPreferences>(),
        sl<LocalStorageService>(),
        sl<ConnectivityService>(),
        sl<AppLogger>(),
        sl<ErrorHandler>(),
        sl<GoRouter>(),
        sl<SettingsCubit>(),
        sl<SettingsRepository>(),
        sl<GetSettingsUseCase>(),
        sl<ChangeLanguageUseCase>(),
        sl<ChangeThemeUseCase>(),
      ];
      for (var i = 0; i < instances.length; i++) {
        expect(repeated[i], same(instances[i]));
      }
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
