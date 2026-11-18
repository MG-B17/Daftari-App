import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/animation/staggered_list_item.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/features/customers/presentation/cubit/customers_list_cubit.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/customers/presentation/widgets/customers_list_body.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:daftariapp/features/customers/presentation/screens/customers_list_screen.dart';
import 'package:daftariapp/features/customers/presentation/screens/customer_form_screen.dart';
import 'package:daftariapp/features/customers/presentation/screens/customer_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../customer_test_setup.dart';

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
        await tester.enterText(
          find.byKey(const ValueKey('customers-search')),
          '٠١٠١٢٣٤٥٦٧٨',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('customers-search')),
        );
        await tester.pumpAndSettle();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('01012345678'),
          150,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('01012345678'), findsOneWidget);
        expect(find.byType(StaggeredListItem), findsWidgets);
        expect(find.text('01124567890'), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('customers-search')),
          'no match',
        );
        await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    expect(find.byType(CustomersListScreen), findsOneWidget);
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
}
