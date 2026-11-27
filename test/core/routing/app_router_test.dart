import 'package:daftariapp/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/animation/screen_transition_animation/fade_transition_page.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/core/services/loacl_storage/local_storage_service.dart';
import 'package:daftariapp/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:daftariapp/features/search/presentation/screens/search_screen.dart';
import 'package:daftariapp/features/security/presentation/cubit/app_lock_cubit.dart';
import 'package:daftariapp/features/security/presentation/screens/pin_lock_screen.dart';
import 'package:daftariapp/features/customers/presentation/screens/customer_form_screen.dart';
import 'package:daftariapp/features/customers/presentation/screens/customer_details_screen.dart';
import 'package:daftariapp/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:daftariapp/features/dashboard/presentation/widgets/top_debtor_row.dart';
import 'package:daftariapp/features/dashboard/presentation/widgets/recent_activity_row.dart';
import 'package:daftariapp/features/dashboard/presentation/widgets/dashboard_summary_card.dart';
import 'package:daftariapp/features/transactions/presentation/screens/transaction_form_screen.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/splash/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daftariapp/core/di/service_locator.dart';

import '../../customer_test_setup.dart';
import '../../security_test_setup.dart';

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

  testWidgets('without storage the dashboard root remains available', (
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

  testWidgets('dashboard quick actions and live rows open their routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = AppRouter.create();
    await tester.pumpWidget(DaftariApp(router: router));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DashboardSummaryCard>(find.byType(DashboardSummaryCard))
          .totalOwedPiasters,
      320000,
    );
    await tester.runAsync(
      () => tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh(),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    for (final entry in {
      'dashboard-register-transaction': TransactionFormScreen,
      'dashboard-new-customer': CustomerFormScreen,
    }.entries) {
      final action = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(entry.value), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
    }
    final debtor = find.byType(TopDebtorRow);
    final id = tester.widget<TopDebtorRow>(debtor).debtor.id;
    await tester.ensureVisible(debtor);
    await tester.tap(debtor);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CustomerDetailsScreen>(find.byType(CustomerDetailsScreen))
          .customerId,
      id,
    );
    router.pop();
    await tester.pumpAndSettle();
    final activity = find.byType(RecentActivityRow);
    await tester.ensureVisible(activity);
    await tester.tap(activity);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CustomerDetailsScreen>(find.byType(CustomerDetailsScreen))
          .customerId,
      id,
    );
    router.pop();
    await tester.pumpAndSettle();
    final viewAll = find.byKey(const ValueKey('dashboard-view-all-debtors'));
    await tester.ensureVisible(viewAll);
    await tester.tap(viewAll);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.customers);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  testWidgets('root search action opens the search route and pops back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final storage = LocalStorageService(await SharedPreferences.getInstance());
    final cubit = SettingsCubit(
      GetSettingsUseCase(SettingsRepositoryImpl(storage)),
      ChangeLanguageUseCase(SettingsRepositoryImpl(storage)),
      ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false)),
    );
    final router = AppRouter.create(localStorage: storage);
    await tester.pumpWidget(DaftariApp(router: router, settingsCubit: cubit));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.root);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(SearchScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('dashboard-search')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      AppRoutes.search,
    );
    expect(find.byKey(const ValueKey('navigation-0')), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsNothing);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      AppRoutes.root,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
    await cubit.close();
  });

  testWidgets('returning-user startup fades from splash into the shell route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
    final storage = LocalStorageService(await SharedPreferences.getInstance());
    final router = AppRouter.create(localStorage: storage);
    addTearDown(router.dispose);

    await tester.pumpWidget(DaftariApp(router: router));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(SplashScreen.displayDuration);
    await tester.pump(const Duration(milliseconds: 100));
    final navigator = tester.widget<Navigator>(find.byType(Navigator).first);
    expect(navigator.pages.last, isA<FadeTransitionPage<dynamic>>());

    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.root);
    expect(find.byType(DashboardScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  for (final completed in [false, true]) {
    testWidgets(
      'PIN-protected startup opens lock immediately and unlocks to onboardingCompleted=$completed destination',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'onboardingCompleted': completed,
        });
        final storage = LocalStorageService(
          await SharedPreferences.getInstance(),
        );
        final lock = await testAppLock(
          repository: TestSecurityRepository(pin: '2468'),
        );
        final router = AppRouter.create(localStorage: storage, appLock: lock);
        addTearDown(() async {
          router.dispose();
          await lock.close();
        });

        await tester.pumpWidget(DaftariApp(router: router, appLockCubit: lock));
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.path, AppRoutes.lock);
        expect(find.byType(PinLockScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        expect(find.byType(DashboardScreen), findsNothing);

        await lock.verify('2468');
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.path,
          completed ? AppRoutes.root : AppRoutes.onboarding,
        );
        expect(
          find.byType(completed ? DashboardScreen : OnboardingScreen),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }

  testWidgets(
    'delayed lock initialization holds on splash and proceeds when ready',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboardingCompleted': true});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      final lock = AppLockCubit(TestSecurityRepository(), SecurityTestClock());
      final router = AppRouter.create(localStorage: storage, appLock: lock);
      addTearDown(() async {
        router.dispose();
        await lock.close();
      });

      await tester.pumpWidget(DaftariApp(router: router, appLockCubit: lock));
      await tester.pump();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.splash);
      expect(find.byType(SplashScreen, skipOffstage: false), findsOneWidget);

      await tester.pump(SplashScreen.displayDuration);
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.splash);
      expect(find.byType(SplashScreen, skipOffstage: false), findsOneWidget);

      await lock.initialize();
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, AppRoutes.root);
      expect(find.byType(DashboardScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
