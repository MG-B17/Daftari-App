import 'dart:async';

import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/animation/staggered_list_item.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/widgets/daftari_loading.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/customers/presentation/screens/customer_details_screen.dart';
import 'package:daftariapp/features/customers/presentation/screens/customers_list_screen.dart';
import 'package:daftariapp/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:daftariapp/features/search/domain/repositories/search_repository.dart';
import 'package:daftariapp/features/search/domain/usecases/watch_search_customers_usecase.dart';
import 'package:daftariapp/features/search/presentation/cubit/search_cubit.dart';
import 'package:daftariapp/features/search/presentation/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lottie/lottie.dart';

import '../../../customer_test_setup.dart';

class _ControlledSearchRepository implements SearchRepository {
  final controller =
      StreamController<Either<AppFailure, List<CustomerEntity>>>.broadcast();
  int watchCalls = 0;

  @override
  Stream<Either<AppFailure, List<CustomerEntity>>> watchSearchableCustomers() {
    watchCalls++;
    return controller.stream;
  }

  Future<void> dispose() => controller.close();
}

Future<void> _pumpUntilSettled(WidgetTester tester, {int maxPumps = 25}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _expectDecodedLottie(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  LottieComposition? composition;
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    final rawFinders = find.byType(RawLottie);
    if (rawFinders.evaluate().isNotEmpty) {
      composition = tester.widget<RawLottie>(rawFinders.first).composition;
      if (composition != null && composition.durationFrames > 0) {
        break;
      }
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(composition, isNotNull);
  expect(composition!.durationFrames, greaterThan(0));
}

void main() {
  setUp(() async => setupCustomerTests());
  tearDown(() => sl.reset());

  for (final locale in [const Locale('ar'), const Locale('en')]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        '${locale.languageCode} $theme empty query, matches, no results, and clear',
        (tester) async {
          final router = AppRouter.create();
          await tester.pumpWidget(
            DaftariApp(router: router, locale: locale, themeMode: theme),
          );
          await tester.pumpAndSettle();
          router.go(AppRoutes.search);
          await _pumpUntilSettled(tester);

          expect(find.byType(SearchScreen), findsOneWidget);
          expect(
            Directionality.of(tester.element(find.byType(SearchScreen))),
            locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(find.byIcon(Icons.mic), findsNothing);
          expect(
            find.byKey(const ValueKey('search-empty-state')),
            findsOneWidget,
          );
          expect(find.text('Mohamed Abdel Fattah'), findsNothing);
          await _expectDecodedLottie(tester);

          // Search with Arabic-Indic digits matching Western-stored phone.
          await tester.enterText(
            find.byKey(const ValueKey('search-input')),
            '٠١٠١٢٣٤٥٦٧٨',
          );
          await _pumpUntilSettled(tester);
          expect(find.text('Mohamed Abdel Fattah'), findsOneWidget);
          expect(find.text('01012345678'), findsOneWidget);
          expect(find.byType(StaggeredListItem), findsOneWidget);
          expect(find.text('Ahmed El Shenawy'), findsNothing);

          // Search with no matching results.
          await tester.enterText(
            find.byKey(const ValueKey('search-input')),
            'no match',
          );
          await _pumpUntilSettled(tester);
          expect(
            find.byKey(const ValueKey('search-no-results')),
            findsOneWidget,
          );
          expect(
            find.text(
              locale.languageCode == 'ar'
                  ? 'لا يوجد عملاء يطابقون البحث.'
                  : 'No customers match your search.',
            ),
            findsOneWidget,
          );
          await _expectDecodedLottie(tester);

          // Clear query returns to empty state.
          await tester.tap(find.byKey(const ValueKey('search-clear')));
          await _pumpUntilSettled(tester);
          expect(
            find.byKey(const ValueKey('search-empty-state')),
            findsOneWidget,
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 1));
          router.dispose();
        },
      );
    }
  }

  testWidgets('hides soft-deleted customers from search results', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final db = sl<AppDatabase>();
      final customers = await db.customerDao.watchActiveCustomers().first;
      final ahmed = customers.firstWhere((c) => c.name == 'Ahmed El Shenawy');
      await db.customerDao.softDeleteCustomer(ahmed.id);
    });

    final router = AppRouter.create();
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    router.go(AppRoutes.search);
    await _pumpUntilSettled(tester);

    await tester.enterText(find.byKey(const ValueKey('search-input')), 'Ahmed');
    await _pumpUntilSettled(tester);
    expect(find.text('Ahmed El Shenawy'), findsNothing);
    expect(find.byKey(const ValueKey('search-no-results')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('search-input')),
      'Mohamed',
    );
    await _pumpUntilSettled(tester);
    expect(find.text('Mohamed Abdel Fattah'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  testWidgets(
    'Home -> Search -> Details -> Back preserves results -> Back returns to Home',
    (tester) async {
      final router = AppRouter.create();
      await tester.pumpWidget(
        DaftariApp(router: router, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('navigation-0')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('dashboard-search')));
      await _pumpUntilSettled(tester);
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        AppRoutes.search,
      );
      expect(find.byKey(const ValueKey('navigation-0')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('search-input')),
        'Mohamed',
      );
      await _pumpUntilSettled(tester);
      expect(find.text('Mohamed Abdel Fattah'), findsOneWidget);

      await tester.tap(find.text('Mohamed Abdel Fattah'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerDetailsScreen), findsOneWidget);

      // Back from Details -> Search with results preserved.
      await tester.tap(find.byTooltip('Back'));
      await _pumpUntilSettled(tester);
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        AppRoutes.search,
      );
      expect(find.text('Mohamed Abdel Fattah'), findsOneWidget);

      // Back from Search -> Home.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        AppRoutes.root,
      );
      expect(find.byKey(const ValueKey('navigation-0')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );

  testWidgets(
    'Customers -> Search -> Details -> Back preserves results -> Back returns to Customers',
    (tester) async {
      final router = AppRouter.create();
      await tester.pumpWidget(
        DaftariApp(router: router, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      router.go(AppRoutes.customers);
      await tester.pumpAndSettle();
      expect(find.byType(CustomersListScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('customers-search')));
      await _pumpUntilSettled(tester);
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        AppRoutes.search,
      );
      expect(find.byKey(const ValueKey('navigation-0')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('search-input')),
        'Karim',
      );
      await _pumpUntilSettled(tester);
      expect(find.text('Umm Karim'), findsOneWidget);

      await tester.tap(find.text('Umm Karim'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerDetailsScreen), findsOneWidget);

      // Back from Details -> Search with results preserved.
      await tester.tap(find.byTooltip('Back'));
      await _pumpUntilSettled(tester);
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(find.text('Umm Karim'), findsOneWidget);

      // Back from Search -> Customers.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomersListScreen), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        AppRoutes.customers,
      );
      expect(find.byKey(const ValueKey('navigation-0')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );

  testWidgets('reduced motion uses static fallback icons and semantics', (
    tester,
  ) async {
    final router = AppRouter.create();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: DaftariApp(router: router, locale: const Locale('en')),
      ),
    );
    await tester.pumpAndSettle();
    router.go(AppRoutes.search);
    await tester.pumpAndSettle();

    expect(find.byType(Lottie), findsNothing);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Search illustration'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('search-input')),
      'nothing',
    );
    await tester.pumpAndSettle();

    expect(find.byType(Lottie), findsNothing);
    expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    expect(
      find.bySemanticsLabel('No matching customers found'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  testWidgets('shows shared loader while loading and inline error with retry', (
    tester,
  ) async {
    final repo = _ControlledSearchRepository();
    addTearDown(repo.dispose);
    final router = AppRouter.create(
      createSearchCubit: () => SearchCubit(WatchSearchCustomersUseCase(repo)),
    );
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    router.go(AppRoutes.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(DaftariLoading), findsOneWidget);

    repo.controller.add(const Left(AppFailure(AppErrorCode.database)));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not access customer data. Please try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.byType(DaftariLoading), findsOneWidget);
    expect(repo.watchCalls, 2);
    expect(repo.controller.hasListener, isTrue);

    repo.controller.add(const Right([]));
    await _pumpUntilSettled(tester);
    expect(find.byKey(const ValueKey('search-empty-state')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });
}
