import 'dart:async';

import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/services/contact_picker/contact_picker_service.dart';
import 'package:daftariapp/core/theme/theme_controller/theme_switcher_cubit.dart';
import 'package:daftariapp/core/utils/money_utils.dart';
import 'package:daftariapp/core/widgets/app_confirmation_dialog.dart';
import 'package:daftariapp/core/widgets/app_error_dialog.dart';
import 'package:daftariapp/core/widgets/app_success_dialog.dart';
import 'package:daftariapp/core/widgets/daftari_loading.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/customers/domain/repositories/customer_repository.dart';
import 'package:daftariapp/features/customers/domain/usecases/create_customer_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/pick_contact_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/soft_delete_customer_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/update_customer_usecase.dart';
import 'package:daftariapp/features/customers/domain/usecases/watch_customer_details_usecase.dart';
import 'package:daftariapp/features/customers/presentation/cubit/customer_details_cubit.dart';
import 'package:daftariapp/features/customers/presentation/cubit/customer_form_cubit.dart';
import 'package:daftariapp/features/customers/presentation/screens/customer_details_screen.dart';
import 'package:daftariapp/features/customers/presentation/screens/customer_form_screen.dart';
import 'package:daftariapp/features/customers/presentation/screens/customers_list_screen.dart';
import 'package:daftariapp/features/customers/presentation/widgets/customer_details_body.dart';
import 'package:daftariapp/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:daftariapp/features/search/presentation/screens/search_screen.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/settings/presentation/screens/settings_screen.dart';
import 'package:daftariapp/features/settings/presentation/widgets/settings_section_card.dart';
import 'package:daftariapp/features/statements/presentation/screens/statement_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:lottie/lottie.dart';

import '../../customer_test_setup.dart';
import '../../security_test_setup.dart';

class _ControlledCustomerRepository implements CustomerRepository {
  final details =
      StreamController<Either<AppFailure, CustomerEntity?>>.broadcast();
  Completer<Either<AppFailure, CustomerEntity>>? pendingCreate;
  Completer<Either<AppFailure, bool>>? pendingUpdate;
  Completer<Either<AppFailure, bool>>? pendingDelete;
  Either<AppFailure, CustomerEntity>? createResult;
  Either<AppFailure, bool> updateResult = const Right(true);
  Either<AppFailure, bool> deleteResult = const Right(true);
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;

  @override
  Stream<Either<AppFailure, CustomerEntity?>> watchCustomerDetails(String id) =>
      details.stream;

  @override
  Future<Either<AppFailure, CustomerEntity>> createCustomer({
    required String name,
    String? phone,
    String? notes,
  }) async {
    createCalls++;
    if (pendingCreate != null) return pendingCreate!.future;
    return createResult ??
        Right(
          CustomerEntity(
            id: 'created-1',
            name: name,
            phone: phone,
            notes: notes,
            balancePiasters: 0,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        );
  }

  @override
  Future<Either<AppFailure, bool>> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? notes,
  }) async {
    updateCalls++;
    if (pendingUpdate != null) return pendingUpdate!.future;
    return updateResult;
  }

  @override
  Future<Either<AppFailure, bool>> softDeleteCustomer(String id) async {
    deleteCalls++;
    if (pendingDelete != null) return pendingDelete!.future;
    return deleteResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Future<void> dispose() => details.close();
}

void main() {
  late AppDatabase db;
  setUp(() async => db = await setupCustomerTests());
  tearDown(() => sl.reset());
  for (final locale in [const Locale('ar'), const Locale('en')]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${locale.languageCode} $theme form and details', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final router = AppRouter.create();
        await tester.pumpWidget(
          DaftariApp(router: router, locale: locale, themeMode: theme),
        );
        await tester.pumpAndSettle();
        router.go('/customers/new');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('customer-name')), findsOneWidget);
        expect(
          Directionality.of(
            tester.element(find.byKey(const ValueKey('customer-name'))),
          ),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(find.byKey(const ValueKey('customer-phone')), findsOneWidget);
        expect(find.byKey(const ValueKey('customer-notes')), findsOneWidget);
        final id = await tester.runAsync(
          () async => (await db.customerDao.watchActiveCustomers().first)
              .firstWhere((c) => c.phone == '01124567890')
              .id,
        );
        router.go('/customers/$id');
        await tester.pumpAndSettle();
        expect(find.text('01124567890'), findsOneWidget);
        expect(find.byKey(const ValueKey('customer-call')), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('customer-statement')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('customer-statement')));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<StatementScreen>(find.byType(StatementScreen))
              .customerId,
          id,
        );
        expect(find.byKey(const ValueKey('statement-balance')), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        router.go('/customers/$id/edit');
        await tester.pumpAndSettle();
        expect(find.text('01124567890'), findsOneWidget);
        router.go('/customers/missing');
        await tester.pumpAndSettle();
        expect(
          find.text(
            locale.languageCode == 'ar'
                ? 'العميل غير موجود'
                : 'Customer not found',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        router.dispose();
      });
    }
  }

  testWidgets('call opens tel URI and reports failure', (tester) async {
    Uri? received;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: CustomerDetailsBody(
              customer: CustomerEntity(
                id: '1',
                name: 'Test',
                phone: '01012345678',
                notes: null,
                balancePiasters: 0,
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
              launchPhone: (uri) async {
                received = uri;
                return false;
              },
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customer-call')));
    await tester.pumpAndSettle();
    expect(received.toString(), 'tel:01012345678');
    expect(find.text('Could not open the phone app.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  testWidgets('import and save a contact to the live ledger', (tester) async {
    await sl.unregister<ContactPickerService>();
    sl.registerSingleton<ContactPickerService>(
      ContactPickerService(
        pickContact: () async =>
            Contact(fullName: 'New Contact', phoneNumbers: ['01012345678']),
      ),
    );
    final router = AppRouter.create();
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    router.go('/customers/new');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import from contacts'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('customer-name')),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('New Contact'), findsOneWidget);
    expect(find.text('01012345678'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save customer'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Save customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save customer'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSuccessDialog), findsOneWidget);
    await tester.ensureVisible(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSuccessDialog), findsNothing);
    expect(find.byType(CustomersListScreen), findsOneWidget);
    final records = await tester.runAsync(
      () => db.customerDao.watchActiveCustomers().first,
    );
    expect(
      records!.any(
        (customer) =>
            customer.name == 'New Contact' && customer.phone == '01012345678',
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  testWidgets(
    'deletion warns about the live balance, shows success dialog once, and preserves ledger records',
    (tester) async {
      final id = await tester.runAsync(
        () async => (await db.customerDao.watchActiveCustomers().first)
            .firstWhere((customer) => customer.phone == '01012345678')
            .id,
      );
      final router = AppRouter.create();
      await tester.pumpWidget(
        DaftariApp(router: router, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      router.go('/customers/$id');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete customer'));
      await tester.pumpAndSettle();
      expect(find.byType(AppConfirmationDialog), findsOneWidget);
      final formatted = MoneyUtils.formatPiasters(320000, locale: 'en');
      expect(
        find.descendant(
          of: find.byType(AppConfirmationDialog),
          matching: find.textContaining(formatted),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete customer').last);
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      await tester.ensureVisible(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(find.byType(CustomersListScreen), findsOneWidget);
      final active = await tester.runAsync(
        () => db.customerDao.watchActiveCustomers().first,
      );
      expect(active!.any((customer) => customer.id == id), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );

  testWidgets(
    'create from Home, Customers FAB, and Empty State returns to each origin after success dialog',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = AppRouter.create();
      await tester.pumpWidget(
        DaftariApp(router: router, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      // 1. Entry point: Home -> New customer.
      router.go(AppRoutes.root);
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dashboard-new-customer')));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerFormScreen), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('customer-name')),
        'From Home',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('customer-save')),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('customer-save')));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      expect(find.text('Customer added'), findsOneWidget);
      await tester.ensureVisible(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);

      // 2. Entry point: Customers List FAB -> New customer.
      router.go(AppRoutes.customers);
      await tester.pumpAndSettle();
      expect(find.byType(CustomersListScreen), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerFormScreen), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('customer-name')),
        'From List FAB',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('customer-save')),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('customer-save')));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      await tester.ensureVisible(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomersListScreen), findsOneWidget);

      // 3. Entry point: Empty state -> Add first customer.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();

      await tester.runAsync(() async {
        final active = await db.customerDao.watchActiveCustomers().first;
        for (final customer in active) {
          await db.customerDao.softDeleteCustomer(customer.id);
        }
      });
      final emptyRouter = AppRouter.create();
      await tester.pumpWidget(
        DaftariApp(router: emptyRouter, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      emptyRouter.go(AppRoutes.customers);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add first customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add first customer'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerFormScreen), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('customer-name')),
        'From Empty State',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('customer-save')),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('customer-save')));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      await tester.ensureVisible(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomersListScreen), findsOneWidget);
      expect(find.text('From Empty State'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      emptyRouter.dispose();
    },
  );

  testWidgets(
    'edit from Details shows update success dialog and returns to Details; delete from Search returns to Search',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = AppRouter.create();
      await tester.pumpWidget(
        DaftariApp(router: router, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      router.go(AppRoutes.customers);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Umm Karim'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerDetailsScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('customer-edit')));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerFormScreen), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('customer-name')),
        'Umm Karim Updated',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('customer-save')),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('customer-save')));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      expect(find.text('Customer updated'), findsOneWidget);
      await tester.ensureVisible(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerDetailsScreen), findsOneWidget);
      expect(find.text('Umm Karim Updated'), findsOneWidget);

      // Delete from Search -> Details -> Back to Search after success dialog.
      router.go(AppRoutes.root);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dashboard-search')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.enterText(
        find.byKey(const ValueKey('search-input')),
        'Karim Updated',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Umm Karim Updated'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerDetailsScreen), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('customer-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('customer-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete customer').last);
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      expect(find.text('Customer deleted'), findsOneWidget);
      await tester.ensureVisible(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(SearchScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );

  testWidgets(
    'inline validation blocks invalid submission without showing error dialog',
    (tester) async {
      final router = AppRouter.create();
      await tester.pumpWidget(
        DaftariApp(router: router, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      router.go(AppRoutes.customerNew);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('customer-phone')),
        '12345',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('customer-save')),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('customer-save')));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorDialog), findsNothing);
      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(find.text('Enter a customer name'), findsOneWidget);
      expect(find.text('Enter a valid Egyptian mobile number'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );

  testWidgets(
    'pending create disables duplicate taps, shows error dialog once with retained input, and uses shared loaders',
    (tester) async {
      final repo = _ControlledCustomerRepository();
      addTearDown(repo.dispose);
      final pending = Completer<Either<AppFailure, CustomerEntity>>();
      repo.pendingCreate = pending;

      await sl.unregister<CustomerFormCubit>();
      sl.registerFactory<CustomerFormCubit>(
        () => CustomerFormCubit(
          CreateCustomerUseCase(repo),
          UpdateCustomerUseCase(repo),
          WatchCustomerDetailsUseCase(repo),
          PickContactUseCase(repo),
        ),
      );
      await sl.unregister<CustomerDetailsCubit>();
      sl.registerFactory<CustomerDetailsCubit>(
        () => CustomerDetailsCubit(
          WatchCustomerDetailsUseCase(repo),
          SoftDeleteCustomerUseCase(repo),
        ),
      );

      final router = AppRouter.create();
      await tester.pumpWidget(
        DaftariApp(router: router, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();

      // Details screen loading uses DaftariLoading instead of CircularProgressIndicator.
      router.go('/customers/loading-id');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(DaftariLoading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Edit form preload uses DaftariLoading instead of CircularProgressIndicator.
      router.go('/customers/loading-id/edit');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(DaftariLoading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Create form pending -> double tap produces 1 call -> error retains input.
      router.go(AppRoutes.customerNew);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('customer-name')),
        'Retained Name',
      );
      await tester.enterText(
        find.byKey(const ValueKey('customer-phone')),
        '01012345678',
      );
      await tester.enterText(
        find.byKey(const ValueKey('customer-notes')),
        'Retained Note',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('customer-save')),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('customer-save')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('customer-save')));
      await tester.pump();
      expect(repo.createCalls, 1);
      expect(find.byType(DaftariLoading), findsOneWidget);

      pending.complete(const Left(AppFailure(AppErrorCode.database)));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorDialog), findsOneWidget);
      expect(
        find.text('Could not access customer data. Please try again.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorDialog), findsNothing);
      expect(find.text('Retained Name'), findsOneWidget);
      expect(find.text('01012345678'), findsOneWidget);
      expect(find.text('Retained Note'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );

  testWidgets(
    'pending delete shows error dialog once and navigating away during pending work stays safe',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _ControlledCustomerRepository();
      addTearDown(repo.dispose);
      final pendingFail = Completer<Either<AppFailure, bool>>();
      repo.pendingDelete = pendingFail;

      await sl.unregister<CustomerDetailsCubit>();
      sl.registerFactory<CustomerDetailsCubit>(
        () => CustomerDetailsCubit(
          WatchCustomerDetailsUseCase(repo),
          SoftDeleteCustomerUseCase(repo),
        ),
      );

      final router = AppRouter.create();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: DaftariApp(router: router, locale: const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();
      router.go(AppRoutes.customers);
      await tester.pumpAndSettle();
      router.push('/customers/c1');
      await tester.pumpAndSettle();
      repo.details.add(
        Right(
          CustomerEntity(
            id: 'c1',
            name: 'Pending Delete',
            phone: '01012345678',
            notes: null,
            balancePiasters: 0,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('customer-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('customer-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete customer').last);
      await tester.pump();
      expect(repo.deleteCalls, 1);
      expect(find.byType(DaftariLoading), findsOneWidget);

      pendingFail.complete(const Left(AppFailure(AppErrorCode.database)));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorDialog), findsOneWidget);
      // Reduced motion uses static icon instead of Lottie.
      expect(find.byType(Lottie), findsNothing);
      await tester.ensureVisible(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerDetailsScreen), findsOneWidget);

      // Start a second delete and navigate back while pending.
      final pendingLeave = Completer<Either<AppFailure, bool>>();
      repo.pendingDelete = pendingLeave;
      await tester.tap(find.byKey(const ValueKey('customer-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete customer').last);
      await tester.pump();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomersListScreen), findsOneWidget);

      pendingLeave.complete(const Right(true));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );

  for (final size in const [Size(800, 1280), Size(1280, 800)]) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      testWidgets(
        'tablet ${size.width.toInt()}x${size.height.toInt()} ${locale.languageCode} details and form match Settings width',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final id = await tester.runAsync(
            () async => (await db.customerDao.watchActiveCustomers().first)
                .firstWhere((c) => c.phone == '01124567890')
                .id,
          );
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

          router.go('/customers/$id');
          await tester.pumpAndSettle();
          final detailsRect = tester.getRect(
            find.byKey(const ValueKey('customer-details-card')),
          );
          expect(detailsRect.left, closeTo(settingsRect.left, 0.1));
          expect(detailsRect.right, closeTo(settingsRect.right, 0.1));
          expect(detailsRect.width, closeTo(settingsRect.width, 0.1));

          router.go(AppRoutes.customerNew);
          await tester.pumpAndSettle();
          final formHeaderRect = tester.getRect(
            find.byKey(const ValueKey('customer-form-header-card')),
          );
          final formFieldsRect = tester.getRect(
            find.byKey(const ValueKey('customer-form-fields-card')),
          );
          for (final rect in [formHeaderRect, formFieldsRect]) {
            expect(rect.left, closeTo(settingsRect.left, 0.1));
            expect(rect.right, closeTo(settingsRect.right, 0.1));
            expect(rect.width, closeTo(settingsRect.width, 0.1));
          }
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 1));
          router.dispose();
        },
      );
    }
  }
}
