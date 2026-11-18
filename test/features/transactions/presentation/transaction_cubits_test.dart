import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
import 'package:daftariapp/features/transactions/presentation/cubit/customer_transactions_cubit.dart';
import 'package:daftariapp/features/transactions/presentation/cubit/transaction_form_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../customer_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() async => db = await setupCustomerTests(seed: false));
  tearDown(() => sl.reset());

  test(
    'create, edit and delete use live data and preserve the past date',
    () async {
      final customer = await db.customerDao.createCustomer(name: 'Test');
      final form = sl<TransactionFormCubit>();
      final customersReady = form.stream.firstWhere(
        (state) => state.customers.isNotEmpty,
      );
      await form.load(null);
      await customersReady.timeout(const Duration(seconds: 5));
      final date = DateTime(2021, 4, 5);
      await form.save(
        customerId: customer.id,
        type: TransactionType.credit,
        amount: '12.34',
        date: date,
        note: 'goods',
      );
      expect(form.state.saved, isTrue);
      final created = (await db.transactionDao.getCustomerTransactions(
        customer.id,
      )).single;
      expect(created.amountPiasters, 1234);
      expect(created.transactionDate, date);
      final edit = sl<TransactionFormCubit>();
      final editReady = edit.stream.firstWhere(
        (state) => state.customers.isNotEmpty && state.transaction != null,
      );
      await edit.load(created.id);
      await editReady.timeout(const Duration(seconds: 5));
      await edit.save(
        customerId: customer.id,
        type: TransactionType.payment,
        amount: '5',
        date: date,
      );
      expect(edit.state.saved, isTrue);
      expect((await db.transactionDao.getAuditLogs(created.id)).length, 1);
      final history = sl<CustomerTransactionsCubit>();
      final historyReady = history.stream.firstWhere(
        (state) => !state.loading && state.entries.isNotEmpty,
      );
      await history.load(customer.id);
      expect(
        (await historyReady.timeout(const Duration(seconds: 5)))
            .entries
            .single
            .type,
        TransactionType.payment,
      );
      expect(history.state.runningBalances, {created.id: BigInt.from(-500)});
      await history.delete(created.id);
      expect((await db.transactionDao.getAuditLogs(created.id)).length, 2);
      expect(await db.transactionDao.getTransactionById(created.id), isNull);
      await history.close();
      await edit.close();
      await form.close();
    },
  );

  test('missing edit never creates a new transaction', () async {
    final customer = await db.customerDao.createCustomer(name: 'Test');
    final form = sl<TransactionFormCubit>();
    final customersReady = form.stream.firstWhere(
      (state) => state.customers.isNotEmpty,
    );
    await form.load('missing');
    await customersReady.timeout(const Duration(seconds: 5));
    await form.save(
      customerId: customer.id,
      type: TransactionType.credit,
      amount: '10',
      date: DateTime(2020),
    );
    expect(form.state.saved, isFalse);
    expect(
      await db.transactionDao.getCustomerTransactions(customer.id),
      isEmpty,
    );
    await form.close();
  });

  test(
    'running balances follow chronological credit and payment entries',
    () async {
      final customer = await db.customerDao.createCustomer(name: 'Balances');
      final first = await db.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 10000,
        transactionDate: DateTime(2021, 1, 1),
      );
      final second = await db.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.payment,
        amountPiasters: 3000,
        transactionDate: DateTime(2021, 1, 2),
      );
      final history = sl<CustomerTransactionsCubit>();
      final ready = history.stream.firstWhere(
        (state) => state.entries.length == 2,
      );
      await history.load(customer.id);
      final state = await ready.timeout(const Duration(seconds: 5));
      expect(state.runningBalances, {
        first.id: BigInt.from(10000),
        second.id: BigInt.from(7000),
      });
      expect(() => state.runningBalances.clear(), throwsUnsupportedError);
      await history.close();
    },
  );

  test('reloading the form replaces the customer subscription', () async {
    final customer = await db.customerDao.createCustomer(name: 'Test');
    final form = sl<TransactionFormCubit>();
    final first = form.stream.firstWhere((state) => state.customers.isNotEmpty);
    await form.load(null);
    await first.timeout(const Duration(seconds: 5));
    await form.load(null).timeout(const Duration(seconds: 5));
    await form.save(
      customerId: customer.id,
      type: TransactionType.credit,
      amount: '1',
      date: DateTime(2020),
    );
    expect(form.state.saved, isTrue);
    await form.close().timeout(const Duration(seconds: 5));
  });
}
