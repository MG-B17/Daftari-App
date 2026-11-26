import 'dart:async';

import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/animation/staggered_list_item.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/theme/theme_switcher_cubit.dart';
import 'package:daftariapp/core/widgets/daftari_loading.dart';
import 'package:daftariapp/features/customers/domain/repositories/customer_repository.dart';
import 'package:daftariapp/features/customers/domain/usecases/pick_contact_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/watch_customers_usecase.dart';
import 'package:daftariapp/features/customers/presentation/cubit/customers_list_cubit.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/customers/presentation/widgets/customer_list_card.dart';
import 'package:daftariapp/features/customers/presentation/widgets/customers_list_body.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/settings/presentation/screens/settings_screen.dart';
import 'package:daftariapp/features/settings/presentation/widgets/settings_section_card.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:daftariapp/features/customers/presentation/screens/customers_list_screen.dart';
import 'package:daftariapp/features/customers/presentation/screens/customer_form_screen.dart';
import 'package:daftariapp/features/customers/presentation/screens/customer_details_screen.dart';
import 'package:daftariapp/features/search/presentation/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';

import '../../customer_test_setup.dart';
import '../../security_test_setup.dart';

class _ControlledListRepository implements CustomerRepository {
  final controller =
      StreamController<Either<AppFailure, List<CustomerEntity>>>.broadcast();

  @override
  Stream<Either<AppFailure, List<CustomerEntity>>> watchCustomers({
    String query = '',
    CustomerFilter filter = CustomerFilter.all,
    CustomerSort sort = CustomerSort.nameAsc,
  }) => controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Future<void> dispose() => controller.close();
}

void main() {
  setUp(() async => setupCustomerTests());
  tearDown(() => sl.reset());
  for (final locale in [const Locale('ar'), const Locale('en')]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${locale.languageCode} $theme list and search', (
        tester,
      ) async {
        final router = AppRouter.create();
        await tester.pumpWidget(
          DaftariApp(router: router, locale: locale, themeMode: theme),
        );
        await tester.pumpAndSettle();
        router.go(AppRoutes.customers);
        await tester.pumpAndSettle();

        expect(find.byType(CustomersListScreen), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(CustomersListScreen))),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(find.byIcon(Icons.mic), findsNothing);
        expect(find.byKey(const ValueKey('customers-search')), findsOneWidget);
        expect(find.byType(StaggeredListItem), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('customers-search')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(SearchScreen), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('search-input')),
          '٠١٠١٢٣٤٥٦٧٨',
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('01012345678'), findsOneWidget);
        expect(find.byType(StaggeredListItem), findsWidgets);
        expect(find.text('01124567890'), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('search-input')),
          'no match',
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          find.text(
            locale.languageCode == 'ar'
                ? 'لا يوجد عملاء يطابقون البحث.'
                : 'No customers match your search.',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        router.dispose();
      });
    }
  }

  testWidgets('root entry and customer routes resolve', (tester) async {
    final router = AppRouter.create();
    await tester.pumpWidget(DaftariApp(router: router));
    await tester.pumpAndSettle();
    router.go(AppRoutes.root);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dashboard-search')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(SearchScreen), findsOneWidget);
    for (final path in [
      '/customers/new',
      '/customers/1',
      '/customers/1/edit',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(
        find.byType(
          path == '/customers/1' ? CustomerDetailsScreen : CustomerFormScreen,
        ),
        findsOneWidget,
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  testWidgets('filters select settled and owing mock customers', (
    tester,
  ) async {
    final router = AppRouter.create();
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    router.go(AppRoutes.customers);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('customers-filter-settled')),
    );
    await tester.tap(find.byKey(const ValueKey('customers-filter-settled')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Umm Karim'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Umm Karim'), findsOneWidget);
    expect(find.text('Mohamed Abdel Fattah'), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customers-filter-owes')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mohamed Abdel Fattah'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Mohamed Abdel Fattah'), findsOneWidget);
    expect(find.text('Umm Karim'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  testWidgets('sort menu selects balance and recent ordering', (tester) async {
    await tester.runAsync(() async {
      final database = sl<AppDatabase>();
      final customers = await database.customerDao.watchActiveCustomers().first;
      final newest = customers
          .map((customer) => customer.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final target = customers.firstWhere(
        (customer) => customer.name == 'Umm Karim',
      );
      await (database.update(
        database.customers,
      )..where((row) => row.id.equals(target.id))).write(
        CustomersCompanion(
          createdAt: Value(newest.add(const Duration(seconds: 5))),
        ),
      );
    });
    final router = AppRouter.create();
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    router.go(AppRoutes.customers);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customers-sort')));
    await tester.pumpAndSettle();
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Highest balance'), findsOneWidget);
    expect(find.text('Recently added'), findsOneWidget);
    await tester.tap(find.text('Highest balance'));
    await tester.pumpAndSettle();
    final cubit = tester
        .element(find.byType(CustomersListBody))
        .read<CustomersListCubit>();
    expect(cubit.state.sort, CustomerSort.balanceDesc);
    expect(cubit.state.visible.first.name, 'Mohamed Abdel Fattah');
    await tester.tap(find.byKey(const ValueKey('customers-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recently added'));
    await tester.pumpAndSettle();
    expect(cubit.state.sort, CustomerSort.recent);
    expect(cubit.state.visible.first.name, 'Umm Karim');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  testWidgets('empty state offers the first customer action', (tester) async {
    await tester.runAsync(() async {
      final customers = await sl<AppDatabase>().customerDao
          .watchActiveCustomers()
          .first;
      for (final customer in customers) {
        await sl<AppDatabase>().customerDao.softDeleteCustomer(customer.id);
      }
    });
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => BlocProvider(
            create: (_) => sl<CustomersListCubit>()..load(),
            child: const CustomersListScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.customerNew,
          builder: (_, _) => const Scaffold(body: Text('placeholder')),
        ),
      ],
    );
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    expect(find.text('No customers yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Import from contacts'), findsOneWidget);
    await tester.ensureVisible(find.text('Add first customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add first customer'));
    await tester.pumpAndSettle();
    expect(find.text('placeholder'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  testWidgets('uses shared screen loader while loading customers list', (
    tester,
  ) async {
    final repo = _ControlledListRepository();
    addTearDown(repo.dispose);
    await sl.unregister<CustomersListCubit>();
    sl.registerFactory<CustomersListCubit>(
      () => CustomersListCubit(
        WatchCustomersUseCase(repo),
        PickContactUseCase(repo),
      ),
    );
    final router = AppRouter.create();
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    router.go(AppRoutes.customers);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(DaftariLoading), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    repo.controller.add(const Right([]));
    await tester.pumpAndSettle();
    expect(find.byType(DaftariLoading), findsNothing);
    expect(find.text('No customers yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  for (final size in const [Size(800, 1280), Size(1280, 800)]) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      testWidgets(
        'tablet ${size.width.toInt()}x${size.height.toInt()} ${locale.languageCode} list matches Settings width in populated and empty states',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await sl<SettingsCubit>().setLocaleCode(locale.languageCode);
          final security = await testAppLock();
          addTearDown(security.close);
          final router = AppRouter.create();
          await tester.pumpWidget(
            DaftariApp(
              router: router,
              locale: locale,
              settingsCubit: sl<SettingsCubit>(),
              themeSwitcherCubit: sl<ThemeSwitcherCubit>(),
              appLockCubit: security,
            ),
          );
          await tester.pumpAndSettle();

          router.go(AppRoutes.settings);
          await tester.pumpAndSettle();
          expect(find.byType(SettingsScreen), findsOneWidget);
          final settingsRect = tester.getRect(
            find.byType(SettingsSectionCard).first,
          );
          expect(settingsRect.width, greaterThan(520));

          router.go(AppRoutes.customers);
          await tester.pumpAndSettle();
          expect(find.byType(CustomersListScreen), findsOneWidget);
          final searchRect = tester.getRect(
            find.byKey(const ValueKey('customers-search')),
          );
          final cardRect = tester.getRect(find.byType(CustomerListCard).first);
          for (final rect in [searchRect, cardRect]) {
            expect(rect.left, closeTo(settingsRect.left, 0.1));
            expect(rect.right, closeTo(settingsRect.right, 0.1));
            expect(rect.width, closeTo(settingsRect.width, 0.1));
          }

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 1));
          router.dispose();

          await tester.runAsync(() async {
            final db = sl<AppDatabase>();
            final active = await db.customerDao.watchActiveCustomers().first;
            for (final customer in active) {
              await db.customerDao.softDeleteCustomer(customer.id);
            }
          });
          final emptyRouter = AppRouter.create();
          await tester.pumpWidget(
            DaftariApp(
              router: emptyRouter,
              locale: locale,
              settingsCubit: sl<SettingsCubit>(),
              themeSwitcherCubit: sl<ThemeSwitcherCubit>(),
              appLockCubit: security,
            ),
          );
          await tester.pumpAndSettle();
          emptyRouter.go(AppRoutes.customers);
          await tester.pumpAndSettle();
          final emptyCardRect = tester.getRect(
            find.byKey(const ValueKey('customers-empty-card')),
          );
          expect(emptyCardRect.left, closeTo(settingsRect.left, 0.1));
          expect(emptyCardRect.right, closeTo(settingsRect.right, 0.1));
          expect(emptyCardRect.width, closeTo(settingsRect.width, 0.1));
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 1));
          emptyRouter.dispose();
        },
      );
    }
  }

  for (final size in const [Size(320, 640), Size(390, 844)]) {
    testWidgets(
      'phone ${size.width.toInt()}x${size.height.toInt()} RTL list renders cleanly',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = AppRouter.create();
        await tester.pumpWidget(
          DaftariApp(router: router, locale: const Locale('ar')),
        );
        await tester.pumpAndSettle();
        router.go(AppRoutes.customers);
        await tester.pumpAndSettle();

        final cardRect = tester.getRect(find.byType(CustomerListCard).first);
        expect(cardRect.left, greaterThan(0));
        expect(cardRect.right, lessThan(size.width));
        expect(cardRect.left, closeTo(size.width - cardRect.right, 0.1));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        router.dispose();
      },
    );
  }

  testWidgets(
    'long list shows first row immediately, stays scrollable, interactive mid-entrance, and respects reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final db = sl<AppDatabase>();
        for (var i = 0; i < 20; i++) {
          await db.customerDao.createCustomer(
            name: 'Customer ${i.toString().padLeft(2, '0')}',
          );
        }
      });

      final router = AppRouter.create();
      await tester.pumpWidget(
        DaftariApp(router: router, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      router.go(AppRoutes.customers);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      // First row renders without a FadeTransition; subsequent rows stagger.
      final firstItem = find.byWidgetPredicate(
        (widget) => widget is StaggeredListItem && widget.index == 0,
      );
      final secondItem = find.byWidgetPredicate(
        (widget) => widget is StaggeredListItem && widget.index == 1,
      );
      expect(firstItem, findsOneWidget);
      expect(secondItem, findsOneWidget);
      expect(
        find.descendant(of: firstItem, matching: find.byType(FadeTransition)),
        findsNothing,
      );
      expect(
        find.descendant(of: secondItem, matching: find.byType(FadeTransition)),
        findsOneWidget,
      );

      // Tapping a row during its staggered entrance opens details.
      await tester.tap(secondItem);
      await tester.pumpAndSettle();
      expect(find.byType(CustomerDetailsScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomersListScreen), findsOneWidget);

      // Scroll through the long list to the bottom customer smoothly.
      await tester.scrollUntilVisible(
        find.text('Umm Karim'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Umm Karim'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();

      // Reduced motion disables stagger animations across all rows.
      final reducedRouter = AppRouter.create();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: DaftariApp(router: reducedRouter, locale: const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();
      reducedRouter.go(AppRoutes.customers);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(StaggeredListItem),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      reducedRouter.dispose();
    },
  );
}
