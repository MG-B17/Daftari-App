import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/core/services/loacl_storage/local_storage_service.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/theme/theme_controller/theme_switcher_cubit.dart';
import 'package:daftariapp/features/security/presentation/cubit/app_lock_cubit.dart';
import 'package:daftariapp/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../dashboard_test_setup.dart';
import '../../security_test_setup.dart';

class _MockStorage extends Mock implements LocalStorageService {}

class _MockErrorHandler extends Mock implements ErrorHandler {}

ErrorHandler _errorHandler() =>
    ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false));

typedef _ThemeHarness = ({
  GoRouter router,
  SharedPreferences prefs,
  LocalStorageService storage,
  SettingsCubit settingsCubit,
  ThemeSwitcherCubit themeSwitcherCubit,
  AppLockCubit security,
});

Future<_ThemeHarness> _pumpAppOnSettings(
  WidgetTester tester, {
  Map<String, Object> initialPrefs = const {'onboardingCompleted': true},
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({
    'onboardingCompleted': true,
    ...initialPrefs,
  });
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorageService(prefs);
  final repo = SettingsRepositoryImpl(storage);
  final settingsCubit = SettingsCubit(
    GetSettingsUseCase(repo),
    ChangeLanguageUseCase(repo),
    _errorHandler(),
  );
  final themeSwitcherCubit = ThemeSwitcherCubit(storage, _errorHandler());
  final security = await testAppLock();
  final router = AppRouter.create(localStorage: storage, appLock: security);

  await tester.pumpWidget(
    DaftariApp(
      router: router,
      settingsCubit: settingsCubit,
      themeSwitcherCubit: themeSwitcherCubit,
      appLockCubit: security,
    ),
  );
  await tester.pumpAndSettle();
  router.go(AppRoutes.settings);
  await tester.pumpAndSettle();

  return (
    router: router,
    prefs: prefs,
    storage: storage,
    settingsCubit: settingsCubit,
    themeSwitcherCubit: themeSwitcherCubit,
    security: security,
  );
}

Future<void> _disposeHarness(WidgetTester tester, _ThemeHarness harness) async {
  await tester.pumpWidget(const SizedBox());
  harness.router.dispose();
  await harness.settingsCubit.close();
  await harness.themeSwitcherCubit.close();
  await harness.security.close();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(setupDashboardTests);
  tearDown(() => sl.reset());

  setUpAll(() {
    registerFallbackValue(ThemeMode.system);
  });

  testWidgets('existing saved dark preference applies on launch', (
    tester,
  ) async {
    final harness = await _pumpAppOnSettings(
      tester,
      initialPrefs: {'themeMode': 'dark'},
    );
    expect(harness.themeSwitcherCubit.state.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
    await _disposeHarness(tester, harness);
  });

  testWidgets(
    'invalid saved preference falls back to system and follows brightness',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final harness = await _pumpAppOnSettings(
        tester,
        initialPrefs: {'themeMode': 'sepia'},
      );
      expect(harness.themeSwitcherCubit.state.themeMode, ThemeMode.system);
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.light,
      );

      await _disposeHarness(tester, harness);
    },
  );

  testWidgets(
    'Settings selects light, dark and system and survives full app restart',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final harness = await _pumpAppOnSettings(
        tester,
        initialPrefs: {'themeMode': 'light'},
      );
      await _scrollTo(tester, find.byKey(const ValueKey('theme-dark')));

      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.light,
      );

      await tester.tap(find.byKey(const ValueKey('theme-dark')));
      await tester.pumpAndSettle();
      expect(harness.themeSwitcherCubit.state.themeMode, ThemeMode.dark);
      expect(harness.prefs.getString('themeMode'), 'dark');
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );

      await tester.tap(find.byKey(const ValueKey('theme-light')));
      await tester.pumpAndSettle();
      expect(harness.themeSwitcherCubit.state.themeMode, ThemeMode.light);
      expect(harness.prefs.getString('themeMode'), 'light');
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.light,
      );

      await tester.tap(find.byKey(const ValueKey('theme-system')));
      await tester.pumpAndSettle();
      expect(harness.themeSwitcherCubit.state.themeMode, ThemeMode.system);
      expect(harness.prefs.getString('themeMode'), 'system');
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );

      await tester.tap(find.byKey(const ValueKey('theme-dark')));
      await tester.pumpAndSettle();
      await _disposeHarness(tester, harness);

      // Simulate restart with fresh cubits backed by the same SharedPreferences.
      final restartedPrefs = await SharedPreferences.getInstance();
      final restartedStorage = LocalStorageService(restartedPrefs);
      final restartedRepo = SettingsRepositoryImpl(restartedStorage);
      final restartedSettings = SettingsCubit(
        GetSettingsUseCase(restartedRepo),
        ChangeLanguageUseCase(restartedRepo),
        _errorHandler(),
      );
      final restartedTheme = ThemeSwitcherCubit(
        restartedStorage,
        _errorHandler(),
      );
      final restartedSecurity = await testAppLock();
      final restartedRouter = AppRouter.create(
        localStorage: restartedStorage,
        appLock: restartedSecurity,
      );

      await tester.pumpWidget(
        DaftariApp(
          router: restartedRouter,
          settingsCubit: restartedSettings,
          themeSwitcherCubit: restartedTheme,
          appLockCubit: restartedSecurity,
        ),
      );
      await tester.pumpAndSettle();
      restartedRouter.go(AppRoutes.settings);
      await tester.pumpAndSettle();

      expect(restartedTheme.state.themeMode, ThemeMode.dark);
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );

      await tester.pumpWidget(const SizedBox());
      restartedRouter.dispose();
      await restartedSettings.close();
      await restartedTheme.close();
      await restartedSecurity.close();
    },
  );

  testWidgets(
    'explicit light and dark modes ignore device brightness changes',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final harness = await _pumpAppOnSettings(
        tester,
        initialPrefs: {'themeMode': 'light'},
      );
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.light,
      );

      await _scrollTo(tester, find.byKey(const ValueKey('theme-dark')));
      await tester.tap(find.byKey(const ValueKey('theme-dark')));
      await tester.pumpAndSettle();

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );

      await _disposeHarness(tester, harness);
    },
  );

  testWidgets('save failure reverts theme and shows storage error feedback', (
    tester,
  ) async {
    final storage = _MockStorage();
    final handler = _MockErrorHandler();
    when(() => storage.localeCode).thenReturn('ar');
    when(() => storage.themeMode).thenReturn(ThemeMode.light);
    when(() => storage.setThemeMode(any())).thenThrow(const StorageException());
    when(() => handler.handle(any()))
        .thenAnswer((_) async => const AppFailure(AppErrorCode.storage));

    final repo = SettingsRepositoryImpl(storage);
    final settingsCubit = SettingsCubit(
      GetSettingsUseCase(repo),
      ChangeLanguageUseCase(repo),
      handler,
    );
    final themeSwitcherCubit = ThemeSwitcherCubit(storage, handler);
    final router = AppRouter.create();
    final security = await testAppLock();

    await tester.pumpWidget(
      DaftariApp(
        router: router,
        settingsCubit: settingsCubit,
        themeSwitcherCubit: themeSwitcherCubit,
        appLockCubit: security,
      ),
    );
    await tester.pumpAndSettle();
    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const ValueKey('theme-dark')));
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(themeSwitcherCubit.state.themeMode, ThemeMode.light);
    expect(themeSwitcherCubit.state.hasError, isTrue);
    expect(find.text(context.l10n.settingsStorageError), findsOneWidget);
    verify(() => handler.handle(any())).called(1);

    await tester.pumpWidget(const SizedBox());
    router.dispose();
    await settingsCubit.close();
    await themeSwitcherCubit.close();
    await security.close();
  });

  testWidgets(
    'P15-09: reduced motion applies new theme colors immediately without reveal or capture, while motion-enabled runs reveal',
    (tester) async {
      final harness = await _pumpAppOnSettings(
        tester,
        initialPrefs: {'themeMode': 'light'},
      );
      await _scrollTo(tester, find.byKey(const ValueKey('theme-dark')));

      // Enable reduced motion.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures.allOn;
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('theme-dark')));
      await tester.pump();

      var settingsContext = tester.element(find.byType(SettingsScreen));
      final model = ThemeModelInheritedNotifier.of(settingsContext);
      expect(Theme.of(settingsContext).brightness, Brightness.dark);
      expect(
        Theme.of(settingsContext).scaffoldBackgroundColor,
        AppTheme.dark.scaffoldBackgroundColor,
      );
      expect(model.controller.isAnimating, isFalse);
      expect(model.image, isNull);
      expect(
        find.byKey(const ValueKey('ThemeSwitchingAreaFirstChild')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('ThemeSwitchingAreaSecondChild')),
        findsNothing,
      );

      // Re-enable motion and verify the existing animated reveal transition runs.
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('theme-light')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(model.image, isNotNull);
      expect(model.controller.isAnimating, isTrue);
      expect(
        find.byKey(const ValueKey('ThemeSwitchingAreaFirstChild')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ThemeSwitchingAreaSecondChild')),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      settingsContext = tester.element(find.byType(SettingsScreen));
      expect(Theme.of(settingsContext).brightness, Brightness.light);
      expect(
        Theme.of(settingsContext).scaffoldBackgroundColor,
        AppTheme.light.scaffoldBackgroundColor,
      );

      await _disposeHarness(tester, harness);
    },
  );
}
