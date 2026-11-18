import 'package:daftariapp/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_theme_usecase.dart';
import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/local_storage_service.dart';
import 'package:daftariapp/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:daftariapp/features/customers/presentation/screens/customer_form_screen.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/settings/presentation/screens/settings_screen.dart';
import 'package:daftariapp/features/splash/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daftariapp/core/di/service_locator.dart';

import '../../customer_test_setup.dart';

void main() {
  setUp(() async => setupCustomerTests());
  tearDown(() => sl.reset());
  testWidgets('customer subroutes are outside the navigation shell', (
    tester,
  ) async {
    final router = AppRouter.create();
    await tester.pumpWidget(DaftariApp(router: router));
    await tester.pumpAndSettle();
    router.go(AppRoutes.customers);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('navigation-0')), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerFormScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('navigation-0')), findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('navigation-0')), findsOneWidget);
    for (final path in [
      '/customers/new',
      '/customers/1',
      '/customers/1/edit',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(find.byKey(const ValueKey('navigation-0')), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  for (final completed in [false, true]) {
    testWidgets('initial route for onboardingCompleted=$completed', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'onboardingCompleted': completed,
      });
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      final router = AppRouter.create(localStorage: storage);
      await tester.pumpWidget(DaftariApp(router: router));
      await tester.pump();
      expect(router.routeInformationProvider.value.uri.path, '/splash');
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        completed ? '/' : '/onboarding',
      );
      expect(
        find.byType(OnboardingScreen),
        completed ? findsNothing : findsOneWidget,
      );
      if (completed) {
        router.go('/onboarding');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    });
  }

  testWidgets('without storage the placeholder root remains available', (
    tester,
  ) async {
    final router = AppRouter.create();
    await tester.pumpWidget(DaftariApp(router: router));
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/splash');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    router.go('/onboarding');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  testWidgets('root settings action opens the settings route', (tester) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final storage = LocalStorageService(await SharedPreferences.getInstance());
    final cubit = SettingsCubit(
      GetSettingsUseCase(SettingsRepositoryImpl(storage)),
      ChangeLanguageUseCase(SettingsRepositoryImpl(storage)),
      ChangeThemeUseCase(SettingsRepositoryImpl(storage)),
      ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false)),
    );
    final router = AppRouter.create(localStorage: storage);
    await tester.pumpWidget(DaftariApp(router: router, settingsCubit: cubit));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.root);
    expect(find.byType(SettingsScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('الإعدادات'), findsWidgets);

    router.go(AppRoutes.root);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.root);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
    await cubit.close();
  });
}
