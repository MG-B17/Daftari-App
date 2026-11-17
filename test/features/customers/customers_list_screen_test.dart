import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/features/customers/presentation/screens/customers_list_screen.dart';
import 'package:daftariapp/features/customers/presentation/screens/customer_form_screen.dart';
import 'package:daftariapp/features/customers/presentation/screens/customer_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
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
    await tester.tap(find.byKey(const ValueKey('open-customers')));
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
    expect(find.text('Umm Karim'), findsOneWidget);
    expect(find.text('Mohamed Abdel Fattah'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('customers-filter-owes')));
    await tester.pumpAndSettle();
    expect(find.text('Mohamed Abdel Fattah'), findsOneWidget);
    expect(find.text('Umm Karim'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });

  testWidgets('empty state offers the first customer action', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const CustomersListScreen(showMockCustomers: false),
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
    await tester.ensureVisible(find.text('Add first customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add first customer'));
    await tester.pumpAndSettle();
    expect(find.text('placeholder'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
  });
}
