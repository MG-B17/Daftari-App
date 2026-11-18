import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/services/contact_picker_service.dart';
import 'package:daftariapp/core/utils/money_utils.dart';
import 'package:daftariapp/core/widgets/app_confirmation_dialog.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/customers/presentation/widgets/customer_details_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';

import '../../customer_test_setup.dart';

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
    await tester.tap(find.text('Save customer'));
    await tester.pumpAndSettle();
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
    'deletion warns about the live balance and preserves ledger records',
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
      final active = await tester.runAsync(
        () => db.customerDao.watchActiveCustomers().first,
      );
      expect(active!.any((customer) => customer.id == id), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );
}
