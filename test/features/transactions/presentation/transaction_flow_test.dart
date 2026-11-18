import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/utils/money_utils.dart';
import 'package:daftariapp/features/transactions/presentation/widgets/transaction_date_card.dart';
import 'package:daftariapp/features/transactions/presentation/widgets/transaction_history_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../customer_test_setup.dart';

void main() {
  late AppDatabase db;
  setUp(() async => db = await setupCustomerTests(seed: false));
  tearDown(() => sl.reset());

  testWidgets('past date selected in form is saved to the ledger', (
    tester,
  ) async {
    final customer = await db.customerDao.createCustomer(name: 'Date customer');
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = AppRouter.create();
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    router.go('/transactions/new?customerId=${customer.id}');
    await tester.pumpAndSettle();
    await tester.tap(find.text('+50'));
    await tester.ensureVisible(find.byType(TransactionDateCard));
    await tester.tap(find.byType(TransactionDateCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '04/05/2021');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TransactionDateCard>(find.byType(TransactionDateCard)).date,
      DateTime(2021, 4, 5),
    );
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    final transactions = await tester.runAsync(
      () => db.transactionDao.getCustomerTransactions(customer.id),
    );
    expect(transactions!.single.transactionDate, DateTime(2021, 4, 5));
    expect(transactions.single.amountPiasters, 5000);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  testWidgets('editing and deleting refreshes customer and running balances', (
    tester,
  ) async {
    final customer = await db.customerDao.createCustomer(
      name: 'Ledger customer',
    );
    final first = await db.transactionDao.createTransaction(
      customerId: customer.id,
      type: TransactionTypes.credit,
      amountPiasters: 10000,
      transactionDate: DateTime(2021, 1, 1),
      note: 'first',
    );
    final second = await db.transactionDao.createTransaction(
      customerId: customer.id,
      type: TransactionTypes.payment,
      amountPiasters: 3000,
      transactionDate: DateTime(2021, 1, 2),
      note: 'second',
    );
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = AppRouter.create();
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    router.go('/customers/${customer.id}');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();

    TransactionHistoryCard card(String id) => tester
        .widgetList<TransactionHistoryCard>(find.byType(TransactionHistoryCard))
        .singleWhere((card) => card.entry.id == id);
    String money(int amount) => MoneyUtils.formatPiasters(amount, locale: 'en');
    expect(card(first.id).balance, money(10000));
    expect(card(second.id).balance, money(7000));
    expect(find.text(money(7000)), findsOneWidget);

    final firstCard = find.byWidgetPredicate(
      (w) => w is TransactionHistoryCard && w.entry.id == first.id,
    );
    await tester.ensureVisible(
      find.descendant(
        of: firstCard,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: firstCard,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('+50'));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(card(first.id).balance, money(15000));
    expect(card(second.id).balance, money(12000));
    expect(find.text(money(12000)), findsOneWidget);

    await tester.ensureVisible(
      find.descendant(
        of: firstCard,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: firstCard,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is TransactionHistoryCard && w.entry.id == first.id,
      ),
      findsNothing,
    );
    expect(card(second.id).balance, money(-3000));
    expect(find.text(money(-3000)), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });

  testWidgets('history builds cards lazily as the user scrolls', (
    tester,
  ) async {
    final customer = await db.customerDao.createCustomer(name: 'Long history');
    for (var i = 0; i < 30; i++) {
      await db.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 100,
        transactionDate: DateTime(2021, 1, 1).add(Duration(days: i)),
      );
    }
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = AppRouter.create();
    await tester.pumpWidget(
      DaftariApp(router: router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();
    router.go('/customers/${customer.id}');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final initial = tester
        .widgetList<TransactionHistoryCard>(find.byType(TransactionHistoryCard))
        .toList();
    expect(initial, isNotEmpty);
    expect(initial.length, lessThan(30));
    final initialId = initial.first.entry.id;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final later = tester
        .widgetList<TransactionHistoryCard>(find.byType(TransactionHistoryCard))
        .toList();
    expect(later.any((card) => card.entry.id != initialId), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    router.dispose();
  });
}
