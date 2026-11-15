import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/connectivity_service.dart';
import 'package:daftariapp/core/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      ];
      await configureDependencies();
      final repeated = <Object>[
        sl<SharedPreferences>(),
        sl<LocalStorageService>(),
        sl<ConnectivityService>(),
        sl<AppLogger>(),
        sl<ErrorHandler>(),
        sl<GoRouter>(),
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
}
