import 'dart:async';

import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/utils/money_utils.dart';
import 'package:daftariapp/core/widgets/app_confirmation_dialog.dart';
import 'package:daftariapp/core/widgets/app_error_dialog.dart';
import 'package:daftariapp/core/widgets/app_success_dialog.dart';
import 'package:daftariapp/core/widgets/daftari_loading.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/customers/domain/repositories/customer_repository.dart';
import 'package:daftariapp/features/customers/domain/usecases/watch_customers_usecase.dart';
import 'package:daftariapp/features/customers/presentation/screens/customer_details_screen.dart';
import 'package:daftariapp/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
import 'package:daftariapp/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:daftariapp/features/transactions/domain/usecases/create_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/edit_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/get_transaction_by_id_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/soft_delete_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/watch_customer_transactions_usecase.dart';
import 'package:daftariapp/features/transactions/presentation/cubit/customer_transactions_cubit.dart';
import 'package:daftariapp/features/transactions/presentation/cubit/transaction_form_cubit.dart';
import 'package:daftariapp/features/transactions/presentation/widgets/transaction_amount_card.dart';
import 'package:daftariapp/features/transactions/presentation/widgets/transaction_customer_card.dart';
import 'package:daftariapp/features/transactions/presentation/widgets/transaction_date_card.dart';
import 'package:daftariapp/features/transactions/presentation/widgets/transaction_history_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lottie/lottie.dart';

import '../../../customer_test_setup.dart';

class _ControlledCustomerRepository implements CustomerRepository {
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

class _ControlledTransactionRepository implements TransactionRepository {
  final entries =
      StreamController<Either<AppFailure, List<TransactionEntity>>>.broadcast();
  Completer<Either<AppFailure, TransactionEntity?>>? pendingGet;
  Completer<Either<AppFailure, TransactionEntity>>? pendingCreate;
  Completer<Either<AppFailure, TransactionEntity>>? pendingEdit;
  Completer<Either<AppFailure, bool>>? pendingDelete;
  Either<AppFailure, TransactionEntity>? createResult;
  Either<AppFailure, bool> deleteResult = const Right(true);
  int createCalls = 0;
  int editCalls = 0;
  int deleteCalls = 0;

  @override
  Stream<Either<AppFailure, List<TransactionEntity>>> watchCustomerTransactions(
    String customerId,
  ) => entries.stream;

  @override
  Future<Either<AppFailure, TransactionEntity?>> getTransactionById(
    String id,
  ) async {
    if (pendingGet != null) return pendingGet!.future;
    return const Right(null);
  }

  @override
  Future<Either<AppFailure, TransactionEntity>> createTransaction({
    required String customerId,
    required TransactionType type,
    required int amountPiasters,
    required DateTime transactionDate,
    String? note,
  }) async {
    createCalls++;
    if (pendingCreate != null) return pendingCreate!.future;
    return createResult ??
        Right(
          TransactionEntity(
            id: 'tx-created',
            customerId: customerId,
            type: type,
            amountPiasters: amountPiasters,
            transactionDate: transactionDate,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            note: note,
          ),
        );
  }

  @override
  Future<Either<AppFailure, TransactionEntity>> editTransaction({
    required String id,
    required TransactionType type,
    required int amountPiasters,
    required DateTime transactionDate,
    String? note,
  }) async {
    editCalls++;
    if (pendingEdit != null) return pendingEdit!.future;
    return Right(
      TransactionEntity(
        id: id,
        customerId: 'c1',
        type: type,
        amountPiasters: amountPiasters,
        transactionDate: transactionDate,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        note: note,
      ),
    );
  }

  @override
  Future<Either<AppFailure, bool>> softDeleteTransaction(String id) async {
    deleteCalls++;
    if (pendingDelete != null) return pendingDelete!.future;
    return deleteResult;
  }

  Future<void> dispose() => entries.close();
}

Future<void> _dismissDialog(WidgetTester tester, {String label = 'OK'}) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

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
    await tester.tap(find.byKey(const ValueKey('transaction-save')));
    await tester.pumpAndSettle();
    expect(find.byType(AppSuccessDialog), findsOneWidget);
    expect(
      tester.widget<AppSuccessDialog>(find.byType(AppSuccessDialog)).assetPath,
      AppSuccessDialog.transactionAddedAssetPath,
    );
    await _dismissDialog(tester);
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
    await tester.tap(find.byKey(const ValueKey('transaction-save')));
    await tester.pumpAndSettle();
    expect(find.byType(AppSuccessDialog), findsOneWidget);
    expect(find.text('Transaction updated'), findsOneWidget);
    expect(
      tester.widget<AppSuccessDialog>(find.byType(AppSuccessDialog)).assetPath,
      AppSuccessDialog.defaultAssetPath,
    );
    await _dismissDialog(tester);
    expect(find.byType(CustomerDetailsScreen), findsOneWidget);
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
    expect(find.byType(AppConfirmationDialog), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.byType(AppSuccessDialog), findsOneWidget);
    expect(find.text('Transaction deleted'), findsOneWidget);
    await _dismissDialog(tester);
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

  testWidgets(
    'credit, payment from customer details and quick entry from Home show matching success dialogs and refresh balances',
    (tester) async {
      final customer = await db.customerDao.createCustomer(
        name: 'Quick Shop Customer',
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

      // 1. Quick entry from Home -> Record transaction -> credit +100.
      router.go(AppRoutes.root);
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('dashboard-register-transaction')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(TransactionCustomerCard),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick Shop Customer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('+100'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('transaction-save')));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      expect(find.text('Credit recorded'), findsOneWidget);
      expect(
        tester
            .widget<AppSuccessDialog>(find.byType(AppSuccessDialog))
            .assetPath,
        AppSuccessDialog.transactionAddedAssetPath,
      );
      await _dismissDialog(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(
        find.text(MoneyUtils.formatPiasters(10000, locale: 'en')),
        findsWidgets,
      );

      // 2. Customer Details -> Credit (+50) -> balance becomes 150.
      router.go('/customers/${customer.id}');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Owes (credit)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Owes (credit)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+50'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('transaction-save')));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      expect(find.text('Credit recorded'), findsOneWidget);
      expect(
        tester
            .widget<AppSuccessDialog>(find.byType(AppSuccessDialog))
            .assetPath,
        AppSuccessDialog.transactionAddedAssetPath,
      );
      await _dismissDialog(tester);
      expect(find.byType(CustomerDetailsScreen), findsOneWidget);
      expect(
        find.text(MoneyUtils.formatPiasters(15000, locale: 'en')),
        findsOneWidget,
      );

      // 3. Customer Details -> Payment (+50) -> uses debtPaidAssetPath, balance becomes 100.
      await tester.ensureVisible(find.text('Paid (payment)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paid (payment)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+50'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('transaction-save')));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsOneWidget);
      expect(find.text('Payment recorded'), findsOneWidget);
      expect(
        tester
            .widget<AppSuccessDialog>(find.byType(AppSuccessDialog))
            .assetPath,
        AppSuccessDialog.debtPaidAssetPath,
      );
      await _dismissDialog(tester);
      expect(find.byType(CustomerDetailsScreen), findsOneWidget);
      expect(
        find.text(MoneyUtils.formatPiasters(10000, locale: 'en')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );

  testWidgets(
    'inline validation blocks missing customer and zero amount without error dialog',
    (tester) async {
      await db.customerDao.createCustomer(name: 'Inline Validation Customer');
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = AppRouter.create();
      await tester.pumpWidget(
        DaftariApp(router: router, locale: const Locale('en')),
      );
      await tester.pumpAndSettle();
      router.go(AppRoutes.transactionNew);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('transaction-save')));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorDialog), findsNothing);
      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(
        find.byKey(const ValueKey('transaction-customer-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('transaction-amount-error')),
        findsOneWidget,
      );

      // Selecting customer & adding amount clears inline errors.
      await tester.tap(
        find.descendant(
          of: find.byType(TransactionCustomerCard),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inline Validation Customer').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('transaction-customer-error')),
        findsNothing,
      );

      await tester.tap(find.text('+50'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('transaction-amount-error')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );

  testWidgets(
    'rapid double tap produces one ledger change, failed save retains entered values, and loaders use DaftariLoading',
    (tester) async {
      final customer = await db.customerDao.createCustomer(
        name: 'Double Tap Customer',
      );
      final repo = _ControlledTransactionRepository();
      addTearDown(repo.dispose);
      final pendingGet = Completer<Either<AppFailure, TransactionEntity?>>();
      repo.pendingGet = pendingGet;

      await sl.unregister<TransactionFormCubit>();
      sl.registerFactory<TransactionFormCubit>(
        () => TransactionFormCubit(
          sl<WatchCustomersUseCase>(),
          GetTransactionByIdUseCase(repo),
          CreateTransactionUseCase(repo),
          EditTransactionUseCase(repo),
        ),
      );
      await sl.unregister<CustomerTransactionsCubit>();
      sl.registerFactory<CustomerTransactionsCubit>(
        () => CustomerTransactionsCubit(
          WatchCustomerTransactionsUseCase(repo),
          SoftDeleteTransactionUseCase(repo),
        ),
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

      // Edit screen preload uses DaftariLoading and zero CircularProgressIndicator.
      router.go('/transactions/loading-tx/edit');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(DaftariLoading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      pendingGet.complete(const Right(null));
      await tester.pumpAndSettle();

      // Customer details history loading uses DaftariLoading and zero CircularProgressIndicator.
      router.go('/customers/${customer.id}');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(DaftariLoading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Rapid double tap on Save produces 1 call, and failure retains all entered values.
      final pendingSave = Completer<Either<AppFailure, TransactionEntity>>();
      repo.pendingCreate = pendingSave;
      router.go('/transactions/new?customerId=${customer.id}&type=payment');
      await tester.pumpAndSettle();
      await tester.tap(find.text('+200'));
      await tester.pump();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Retained payment note');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('transaction-save')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('transaction-save')));
      await tester.pump();
      expect(repo.createCalls, 1);
      expect(find.byType(DaftariLoading), findsOneWidget);

      pendingSave.complete(const Left(AppFailure(AppErrorCode.database)));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorDialog), findsOneWidget);
      await _dismissDialog(tester);
      expect(find.byType(AppErrorDialog), findsNothing);

      // All entered values remain intact after failure.
      expect(
        tester
            .widget<TransactionAmountCard>(find.byType(TransactionAmountCard))
            .amount,
        '200',
      );
      expect(
        tester
            .widget<TransactionAmountCard>(find.byType(TransactionAmountCard))
            .payment,
        isTrue,
      );
      expect(find.text('Double Tap Customer'), findsOneWidget);
      expect(find.text('Retained payment note'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );

  testWidgets(
    'pending delete shows inline loader, error dialog respects reduced motion, and navigating away stays safe',
    (tester) async {
      final customer = await db.customerDao.createCustomer(
        name: 'Delete Flow Customer',
      );
      final repo = _ControlledTransactionRepository();
      addTearDown(repo.dispose);
      final pendingFail = Completer<Either<AppFailure, bool>>();
      repo.pendingDelete = pendingFail;

      await sl.unregister<CustomerTransactionsCubit>();
      sl.registerFactory<CustomerTransactionsCubit>(
        () => CustomerTransactionsCubit(
          WatchCustomerTransactionsUseCase(repo),
          SoftDeleteTransactionUseCase(repo),
        ),
      );

      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = AppRouter.create();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: DaftariApp(router: router, locale: const Locale('ar')),
        ),
      );
      await tester.pumpAndSettle();
      router.go(AppRoutes.customers);
      await tester.pumpAndSettle();
      router.push('/customers/${customer.id}');
      await tester.pumpAndSettle();

      repo.entries.add(
        Right([
          TransactionEntity(
            id: 'tx-del-1',
            customerId: customer.id,
            type: TransactionType.credit,
            amountPiasters: 5000,
            transactionDate: DateTime(2026, 1, 1),
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            note: 'بقالة',
          ),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      final card = find.byType(TransactionHistoryCard);
      await tester.ensureVisible(
        find.descendant(
          of: card,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف').last);
      await tester.pump();
      expect(repo.deleteCalls, 1);
      expect(find.byType(DaftariLoading), findsOneWidget);
      expect(find.byType(Lottie), findsNothing);

      pendingFail.complete(const Left(AppFailure(AppErrorCode.database)));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorDialog), findsOneWidget);
      expect(find.byType(Lottie), findsNothing);
      await _dismissDialog(tester, label: 'حسناً');
      expect(find.byType(AppErrorDialog), findsNothing);

      // Start second delete and pop back while pending.
      final pendingLeave = Completer<Either<AppFailure, bool>>();
      repo.pendingDelete = pendingLeave;
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف').last);
      await tester.pump();
      router.pop();
      await tester.pumpAndSettle();

      pendingLeave.complete(const Right(true));
      await tester.pumpAndSettle();
      expect(find.byType(AppSuccessDialog), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );

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

  testWidgets(
    'P15-08: failed save keeps draft and reconciles customer picker and retry validation when selected customer becomes inactive during save',
    (tester) async {
      final customersRepo = _ControlledCustomerRepository();
      final txRepo = _ControlledTransactionRepository();
      addTearDown(customersRepo.dispose);
      addTearDown(txRepo.dispose);

      final customerA = CustomerEntity(
        id: 'cust-a',
        name: 'Removed Customer',
        phone: null,
        notes: null,
        balancePiasters: 0,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final customerB = CustomerEntity(
        id: 'cust-b',
        name: 'Active Customer',
        phone: null,
        notes: null,
        balancePiasters: 0,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      await sl.unregister<TransactionFormCubit>();
      sl.registerFactory<TransactionFormCubit>(
        () => TransactionFormCubit(
          WatchCustomersUseCase(customersRepo),
          GetTransactionByIdUseCase(txRepo),
          CreateTransactionUseCase(txRepo),
          EditTransactionUseCase(txRepo),
        ),
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
      router.go('/transactions/new?customerId=${customerA.id}&type=payment');
      await tester.pumpAndSettle();

      customersRepo.controller.add(Right([customerA, customerB]));
      await tester.pumpAndSettle();
      expect(find.text('Removed Customer'), findsOneWidget);

      await tester.tap(find.text('+200'));
      await tester.pump();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Preserved note');
      await tester.pump();

      final pendingSave = Completer<Either<AppFailure, TransactionEntity>>();
      txRepo.pendingCreate = pendingSave;

      await tester.tap(find.byKey(const ValueKey('transaction-save')));
      await tester.pump();
      expect(txRepo.createCalls, 1);

      // Emit a customer list without the selected customer while the save is pending.
      customersRepo.controller.add(Right([customerB]));
      await tester.pump();

      // Fail the save and dismiss the error dialog.
      pendingSave.complete(const Left(AppFailure(AppErrorCode.database)));
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorDialog), findsOneWidget);
      await _dismissDialog(tester);
      expect(find.byType(AppErrorDialog), findsNothing);

      // Amount and note survive while the removed customer is no longer selected.
      expect(
        tester
            .widget<TransactionAmountCard>(find.byType(TransactionAmountCard))
            .amount,
        '200',
      );
      expect(find.text('Preserved note'), findsOneWidget);
      expect(find.text('Removed Customer'), findsNothing);

      // Picker reflects the last emitted list without needing a second stream event.
      final pickerButton = find.descendant(
        of: find.byType(TransactionCustomerCard),
        matching: find.byType(TextButton),
      );
      await tester.ensureVisible(pickerButton);
      await tester.pumpAndSettle();
      await tester.tap(pickerButton);
      await tester.pumpAndSettle();
      expect(find.text('Active Customer'), findsOneWidget);
      expect(find.text('Removed Customer'), findsNothing);
      Navigator.of(tester.element(find.text('Active Customer'))).pop();
      await tester.pumpAndSettle();

      // Retrying Save immediately fails customer validation without calling create again.
      txRepo.pendingCreate = null;
      await tester.tap(find.byKey(const ValueKey('transaction-save')));
      await tester.pumpAndSettle();
      expect(txRepo.createCalls, 1);
      expect(
        find.byKey(const ValueKey('transaction-customer-error')),
        findsOneWidget,
      );
      expect(find.byType(AppErrorDialog), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );
}
