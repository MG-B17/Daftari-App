import 'package:daftariapp/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_theme_usecase.dart';
import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/local_storage_service.dart';
import 'package:daftariapp/features/auth/login/presentation/screens/login_screen.dart';
import 'package:daftariapp/features/auth/sign_up/presentation/screens/register_screen.dart';
import 'package:daftariapp/features/backup/presentation/screens/backup_screen.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/settings/presentation/screens/settings_screen.dart';
import 'package:daftariapp/features/security/presentation/cubit/app_lock_cubit.dart';
import 'package:daftariapp/features/security/presentation/screens/pin_lock_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:daftariapp/features/settings/presentation/widgets/language_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../dashboard_test_setup.dart';
import '../../security_test_setup.dart';

class _Storage extends Mock implements LocalStorageService {}

class _Handler extends Mock implements ErrorHandler {}

typedef _Harness = ({
  GoRouter router,
  LocalStorageService storage,
  SettingsCubit cubit,
  AppLockCubit security,
});

ErrorHandler _errorHandler() =>
    ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false));

Future<_Harness> _pumpSettings(
  WidgetTester tester, {
  String localeCode = 'ar',
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(400, 900),
  TestSecurityRepository? securityRepository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'localeCode': localeCode,
    'themeMode': themeMode.name,
    'onboardingCompleted': true,
  });
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  final cubit = SettingsCubit(
    GetSettingsUseCase(SettingsRepositoryImpl(storage)),
    ChangeLanguageUseCase(SettingsRepositoryImpl(storage)),
    ChangeThemeUseCase(SettingsRepositoryImpl(storage)),
    _errorHandler(),
  );
  final security = await testAppLock(repository: securityRepository);
  final router = AppRouter.create(localStorage: storage, appLock: security);
  await tester.pumpWidget(
    DaftariApp(router: router, settingsCubit: cubit, appLockCubit: security),
  );
  await tester.pumpAndSettle();
  router.go(AppRoutes.settings);
  await tester.pumpAndSettle();
  return (router: router, storage: storage, cubit: cubit, security: security);
}

Future<void> _dispose(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(const SizedBox());
  harness.router.dispose();
  await harness.cubit.close();
  await harness.security.close();
}

Future<void> _digits(WidgetTester tester, String value) async {
  for (final digit in value.split('')) {
    final key = find.widgetWithText(FilledButton, digit);
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pumpAndSettle();
  }
}

/// Scrolls [finder] into view, building it first when the list has not
/// created its element yet.
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

Future<void> _openTile(WidgetTester tester, String label) async {
  await _scrollTo(tester, find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _unlockAndOpenSettings(
  WidgetTester tester,
  _Harness harness, {
  String pin = '2468',
}) async {
  await _digits(tester, pin);
  harness.router.go(AppRoutes.settings);
  await tester.pumpAndSettle();
  expect(find.byType(SettingsScreen), findsOneWidget);
}

void main() {
  setUp(setupDashboardTests);
  tearDown(() => sl.reset());

  setUpAll(() {
    registerFallbackValue(ThemeMode.system);
  });

  testWidgets('security session survives settings and ScreenUtil rebuilds', (
    tester,
  ) async {
    final harness = await _pumpSettings(tester, localeCode: 'en');
    AppLockCubit security() =>
        tester.element(find.byType(SettingsScreen)).read<AppLockCubit>();
    final original = security();
    await original.setup('9876');
    await original.setBiometric(true);
    await harness.cubit.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    await harness.cubit.setLocaleCode('ar');
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(430, 850);
    await tester.pumpAndSettle();
    expect(security(), same(original));
    expect(security().state.settings.isPinEnabled, isTrue);
    expect(security().state.settings.isBiometricEnabled, isTrue);
    await _dispose(tester, harness);
  });

  testWidgets('security setup, cancel and verified disable round trip', (
    tester,
  ) async {
    final harness = await _pumpSettings(tester, localeCode: 'en');
    final cubit = tester
        .element(find.byType(SettingsScreen))
        .read<AppLockCubit>();
    Future<void> openPin() async {
      await _scrollTo(tester, find.text('App PIN'));
      await tester.tap(find.text('App PIN'));
      await tester.pumpAndSettle();
    }

    Future<void> digits(String value) async {
      for (final digit in value.split('')) {
        final key = find.widgetWithText(FilledButton, digit);
        await tester.ensureVisible(key);
        await tester.tap(key);
        await tester.pumpAndSettle();
      }
    }

    await openPin();
    harness.router.pop();
    await tester.pumpAndSettle();
    expect(cubit.state.settings.isPinEnabled, isFalse);
    await openPin();
    await digits('9876');
    await digits('9876');
    expect(cubit.state.settings.isPinEnabled, isTrue);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(PinLockScreen), findsNothing);
    await _scrollTo(tester, find.text('Change PIN'));
    await tester.tap(find.text('Change PIN'));
    await tester.pumpAndSettle();
    await digits('9876');
    await digits('2468');
    await digits('2468');
    expect(cubit.state.settings.isPinEnabled, isTrue);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(PinLockScreen), findsNothing);
    await openPin();
    await digits('2468');
    expect(cubit.state.settings.isPinEnabled, isFalse);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(PinLockScreen), findsNothing);
    await _dispose(tester, harness);
  });

  testWidgets('Arabic settings render RTL sections and the app version', (
    tester,
  ) async {
    final harness = await _pumpSettings(tester);
    final context = tester.element(find.byType(SettingsScreen));
    final l10n = context.l10n;

    expect(Directionality.of(context), TextDirection.rtl);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(l10n.settingsTitle),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.authAccountTitle), findsOneWidget);
    await _scrollTo(tester, find.text(l10n.settingsAppearanceTitle));
    expect(find.text(l10n.settingsAppearanceTitle), findsOneWidget);
    expect(find.text(l10n.settingsThemeLight), findsOneWidget);
    expect(find.text(l10n.settingsThemeDark), findsOneWidget);
    expect(find.text(l10n.settingsThemeSystem), findsOneWidget);
    expect(find.text(l10n.settingsAppearanceCaption), findsOneWidget);
    expect(find.text(l10n.settingsLanguageTitle), findsOneWidget);
    expect(find.text(l10n.settingsLanguageArabic), findsOneWidget);
    await _scrollTo(tester, find.text(l10n.settingsAboutTitle));
    expect(find.text(l10n.settingsAboutTitle), findsOneWidget);
    expect(find.text(l10n.settingsVersionLabel), findsOneWidget);
    expect(
      find.text('${AppConstants.appVersion} (${l10n.settingsVersionStable})'),
      findsOneWidget,
    );
    await _dispose(tester, harness);
  });

  testWidgets('English settings render LTR', (tester) async {
    final harness = await _pumpSettings(tester, localeCode: 'en');
    final context = tester.element(find.byType(SettingsScreen));
    expect(Directionality.of(context), TextDirection.ltr);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Settings')),
      findsOneWidget,
    );
    await _scrollTo(tester, find.text('Appearance'));
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('App language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    await _scrollTo(tester, find.text('About'));
    expect(find.text('About'), findsOneWidget);
    await _dispose(tester, harness);
  });

  testWidgets('system mode follows platform brightness changes', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final harness = await _pumpSettings(tester, themeMode: ThemeMode.system);
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.light,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
    await _dispose(tester, harness);
  });

  testWidgets('theme changes apply immediately and persist', (tester) async {
    final harness = await _pumpSettings(tester, themeMode: ThemeMode.light);
    await _scrollTo(tester, find.byKey(const ValueKey('theme-light')));
    var context = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(
      tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('theme-light')),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color,
      context.colorScheme.primary,
    );

    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    context = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(harness.storage.themeMode, ThemeMode.dark);
    expect(harness.cubit.state.themeMode, ThemeMode.dark);

    await tester.tap(find.byKey(const ValueKey('theme-system')));
    await tester.pumpAndSettle();
    expect(harness.storage.themeMode, ThemeMode.system);
    expect(harness.cubit.state.themeMode, ThemeMode.system);

    await tester.tap(find.byKey(const ValueKey('theme-light')));
    await tester.pumpAndSettle();
    context = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(harness.storage.themeMode, ThemeMode.light);

    final restarted = SettingsCubit(
      GetSettingsUseCase(SettingsRepositoryImpl(harness.storage)),
      ChangeLanguageUseCase(SettingsRepositoryImpl(harness.storage)),
      ChangeThemeUseCase(SettingsRepositoryImpl(harness.storage)),
      _errorHandler(),
    );
    expect(restarted.state.themeMode, ThemeMode.light);
    await restarted.close();
    await _dispose(tester, harness);
  });

  testWidgets('language sheet switches locale and direction immediately', (
    tester,
  ) async {
    final harness = await _pumpSettings(tester);
    var context = tester.element(find.byType(SettingsScreen));
    expect(Directionality.of(context), TextDirection.rtl);

    await _scrollTo(tester, find.byKey(const ValueKey('language-tile')));
    await tester.tap(find.byKey(const ValueKey('language-tile')));
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePickerSheet), findsOneWidget);
    expect(find.text(context.l10n.settingsLanguagePickerTitle), findsOneWidget);
    expect(find.text(context.l10n.settingsLanguageHint), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('language-option-ar')), findsOneWidget);
    expect(find.byKey(const ValueKey('language-option-en')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('language-option-en')));
    await tester.pumpAndSettle();
    context = tester.element(find.byType(SettingsScreen));
    expect(Directionality.of(context), TextDirection.ltr);
    expect(find.byType(LanguagePickerSheet), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Settings')),
      findsOneWidget,
    );
    expect(harness.storage.localeCode, 'en');
    expect(harness.cubit.state.localeCode, 'en');

    await _scrollTo(tester, find.byKey(const ValueKey('language-tile')));
    await tester.tap(find.byKey(const ValueKey('language-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-option-ar')));
    await tester.pumpAndSettle();
    context = tester.element(find.byType(SettingsScreen));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('الإعدادات'),
      ),
      findsOneWidget,
    );
    expect(harness.storage.localeCode, 'ar');

    final restarted = SettingsCubit(
      GetSettingsUseCase(SettingsRepositoryImpl(harness.storage)),
      ChangeLanguageUseCase(SettingsRepositoryImpl(harness.storage)),
      ChangeThemeUseCase(SettingsRepositoryImpl(harness.storage)),
      _errorHandler(),
    );
    expect(restarted.state.localeCode, 'ar');
    await restarted.close();
    await _dispose(tester, harness);
  });

  testWidgets('storage failure reverts the theme and shows the error', (
    tester,
  ) async {
    final storage = _Storage();
    final handler = _Handler();
    when(() => storage.localeCode).thenReturn('ar');
    when(() => storage.themeMode).thenReturn(ThemeMode.light);
    when(() => storage.setThemeMode(any())).thenThrow(const StorageException());
    when(() => handler.handle(any()))
        .thenAnswer((_) async => const AppFailure(AppErrorCode.storage));
    final cubit = SettingsCubit(
      GetSettingsUseCase(SettingsRepositoryImpl(storage)),
      ChangeLanguageUseCase(SettingsRepositoryImpl(storage)),
      ChangeThemeUseCase(SettingsRepositoryImpl(storage)),
      handler,
    );
    final router = AppRouter.create();
    final security = await testAppLock();
    await tester.pumpWidget(
      DaftariApp(router: router, settingsCubit: cubit, appLockCubit: security),
    );
    await tester.pumpAndSettle();
    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(const ValueKey('theme-dark')));
    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(SettingsScreen));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(cubit.state.hasError, isTrue);
    expect(cubit.state.themeMode, ThemeMode.light);
    expect(find.text(context.l10n.settingsStorageError), findsOneWidget);
    verify(() => handler.handle(any())).called(1);

    await tester.pumpWidget(const SizedBox());
    router.dispose();
    await cubit.close();
    await security.close();
  });

  testWidgets('settings fit a narrow RTL screen with enlarged text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = await _pumpSettings(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);

    await _scrollTo(tester, find.byKey(const ValueKey('language-tile')));
    await tester.tap(find.byKey(const ValueKey('language-tile')));
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePickerSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('language-option-en')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _dispose(tester, harness);
  });

  testWidgets('backup section opens the backup screen', (tester) async {
    final harness = await _pumpSettings(tester, localeCode: 'en');
    final l10n = tester.element(find.byType(SettingsScreen)).l10n;
    expect(find.text(l10n.backupSectionTitle), findsOneWidget);

    await _openTile(tester, l10n.backupManageTitle);

    expect(find.byType(BackupScreen), findsOneWidget);
    expect(harness.router.state.uri.path, AppRoutes.settingsBackup);
    harness.router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await _dispose(tester, harness);
  });

  testWidgets('account section opens the login screen', (tester) async {
    final harness = await _pumpSettings(tester, localeCode: 'en');

    await _scrollTo(tester, find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(harness.router.state.uri.path, AppRoutes.authLogin);
    await _dispose(tester, harness);
  });

  testWidgets('Settings create account switches to login and back', (
    tester,
  ) async {
    final harness = await _pumpSettings(tester, localeCode: 'en');
    final l10n = tester.element(find.byType(SettingsScreen)).l10n;
    await _openTile(tester, l10n.authAccountCreate);
    expect(find.byType(RegisterScreen), findsOneWidget);

    await _openTile(tester, l10n.authSignInLink);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(harness.router.state.uri.path, AppRoutes.authLogin);

    await _openTile(tester, l10n.authCreateAccount);
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(harness.router.state.uri.path, AppRoutes.authRegister);

    harness.router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await _dispose(tester, harness);
  });

  testWidgets('enabling PIN returns to Settings instead of dashboard', (
    tester,
  ) async {
    final harness = await _pumpSettings(tester, localeCode: 'en');
    await _openTile(tester, 'App PIN');
    expect(find.text('Create your PIN'), findsOneWidget);

    await _digits(tester, '1357');
    await _digits(tester, '1357');

    expect(harness.security.state.settings.isPinEnabled, isTrue);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      AppRoutes.settings,
    );
    await _dispose(tester, harness);
  });

  testWidgets('changing PIN returns to Settings instead of dashboard', (
    tester,
  ) async {
    final repository = TestSecurityRepository(pin: '2468');
    final harness = await _pumpSettings(
      tester,
      localeCode: 'en',
      securityRepository: repository,
    );
    await _unlockAndOpenSettings(tester, harness);

    await _openTile(tester, 'Change PIN');
    await _digits(tester, '2468');
    await _digits(tester, '1357');
    await _digits(tester, '1357');

    expect(repository.pin, '1357');
    expect(harness.security.state.settings.isPinEnabled, isTrue);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      AppRoutes.settings,
    );
    await _dispose(tester, harness);
  });

  testWidgets('disabling PIN returns to Settings instead of dashboard', (
    tester,
  ) async {
    final repository = TestSecurityRepository(pin: '2468');
    final harness = await _pumpSettings(
      tester,
      localeCode: 'en',
      securityRepository: repository,
    );
    await _unlockAndOpenSettings(tester, harness);

    await _openTile(tester, 'App PIN');
    await _digits(tester, '2468');

    expect(repository.pin, isNull);
    expect(harness.security.state.settings.isPinEnabled, isFalse);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      AppRoutes.settings,
    );
    await _dispose(tester, harness);
  });
}
