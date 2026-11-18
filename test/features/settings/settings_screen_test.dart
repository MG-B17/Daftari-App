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
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/settings/presentation/screens/settings_screen.dart';
import 'package:daftariapp/features/settings/presentation/widgets/language_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../dashboard_test_setup.dart';

class _Storage extends Mock implements LocalStorageService {}

class _Handler extends Mock implements ErrorHandler {}

typedef _Harness = ({
  GoRouter router,
  LocalStorageService storage,
  SettingsCubit cubit,
});

ErrorHandler _errorHandler() =>
    ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false));

Future<_Harness> _pumpSettings(
  WidgetTester tester, {
  String localeCode = 'ar',
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(400, 900),
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
  final router = AppRouter.create(localStorage: storage);
  await tester.pumpWidget(DaftariApp(router: router, settingsCubit: cubit));
  await tester.pumpAndSettle();
  router.go(AppRoutes.settings);
  await tester.pumpAndSettle();
  return (router: router, storage: storage, cubit: cubit);
}

Future<void> _dispose(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(const SizedBox());
  harness.router.dispose();
  await harness.cubit.close();
}

void main() {
  setUp(setupDashboardTests);
  tearDown(() => sl.reset());

  setUpAll(() {
    registerFallbackValue(ThemeMode.system);
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
    expect(find.text(l10n.settingsAppearanceTitle), findsOneWidget);
    expect(find.text(l10n.settingsThemeLight), findsOneWidget);
    expect(find.text(l10n.settingsThemeDark), findsOneWidget);
    expect(find.text(l10n.settingsThemeSystem), findsOneWidget);
    expect(find.text(l10n.settingsAppearanceCaption), findsOneWidget);
    expect(find.text(l10n.settingsLanguageTitle), findsOneWidget);
    expect(find.text(l10n.settingsLanguageArabic), findsOneWidget);
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
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('App language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
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
    await tester.pumpWidget(DaftariApp(router: router, settingsCubit: cubit));
    await tester.pumpAndSettle();
    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();

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
  });

  testWidgets('settings fit a narrow RTL screen with enlarged text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final harness = await _pumpSettings(tester, size: const Size(320, 640));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('language-tile')));
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePickerSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('language-option-en')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _dispose(tester, harness);
  });
}
