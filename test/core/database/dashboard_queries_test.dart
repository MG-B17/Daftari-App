import 'dart:async';

import 'package:daftariapp/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  final start = DateTime(2026, 11, 18);
  final end = DateTime(2026, 11, 19);

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('collections use payment date and half-open local day bounds', () async {
    final customer = await database.customerDao.createCustomer(name: 'Active');
    Future<TransactionRecord> entry(String type, int amount, DateTime date) =>
        database.transactionDao.createTransaction(
          customerId: customer.id,
          type: type,
          amountPiasters: amount,
          transactionDate: date,
        );
    await entry(TransactionTypes.payment, 101, start);
    await entry(
      TransactionTypes.payment,
      202,
      end.subtract(const Duration(seconds: 1)),
    );
    await entry(
      TransactionTypes.payment,
      400,
      start.subtract(const Duration(seconds: 1)),
    );
    await entry(TransactionTypes.payment, 800, end);
    await entry(TransactionTypes.credit, 1600, start);
    final deleted = await entry(TransactionTypes.payment, 3200, start);
    await database.transactionDao.softDeleteTransaction(deleted.id);
    expect(
      await database.transactionDao
          .watchTodayPaymentsPiasters(start, end)
          .first,
      303,
    );
    await database.customerDao.softDeleteCustomer(customer.id);
    expect(
      await database.transactionDao
          .watchTodayPaymentsPiasters(start, end)
          .first,
      0,
    );
  });

  test(
    'joined activity limits and orders by date, creation, then id',
    () async {
      final customer = await database.customerDao.createCustomer(
        name: 'Original',
      );
      for (final id in ['a', 'c', 'b']) {
        await database
            .into(database.transactions)
            .insert(
              TransactionsCompanion.insert(
                id: id,
                customerId: customer.id,
                type: TransactionTypes.credit,
                amountPiasters: 1,
                transactionDate: start,
                createdAt: Value(start),
                updatedAt: Value(start),
              ),
            );
      }
      final older = await database.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 1,
        transactionDate: start.subtract(const Duration(days: 1)),
      );
      final rows = await database.transactionDao
          .watchRecentTransactionsWithCustomer(limit: 2)
          .first;
      expect(rows.map((row) => row.transaction.id), ['c', 'b']);
      expect(rows.first.customer.name, 'Original');
      expect(rows.any((row) => row.transaction.id == older.id), isFalse);
    },
  );

  test('both watches react to edits, deletions and customer changes', () async {
    final customer = await database.customerDao.createCustomer(name: 'Before');
    final entry = await database.transactionDao.createTransaction(
      customerId: customer.id,
      type: TransactionTypes.payment,
      amountPiasters: 101,
      transactionDate: start,
    );
    final payments = StreamIterator(
      database.transactionDao.watchTodayPaymentsPiasters(start, end),
    );
    final activity = StreamIterator(
      database.transactionDao.watchRecentTransactionsWithCustomer(),
    );
    addTearDown(payments.cancel);
    addTearDown(activity.cancel);
    await payments.moveNext();
    await activity.moveNext();
    expect(payments.current, 101);
    await database.transactionDao.editTransaction(
      id: entry.id,
      type: TransactionTypes.payment,
      amountPiasters: 205,
      transactionDate: start,
    );
    await payments.moveNext();
    await activity.moveNext();
    expect(payments.current, 205);
    expect(activity.current.single.transaction.amountPiasters, 205);
    await database.customerDao.updateCustomer(id: customer.id, name: 'After');
    await activity.moveNext();
    expect(activity.current.single.customer.name, 'After');
    await database.transactionDao.softDeleteTransaction(entry.id);
    await payments.moveNext();
    await activity.moveNext();
    expect(payments.current, 0);
    expect(activity.current, isEmpty);
    await database.transactionDao.createTransaction(
      customerId: customer.id,
      type: TransactionTypes.payment,
      amountPiasters: 500,
      transactionDate: start,
    );
    await payments.moveNext();
    await activity.moveNext();
    await database.customerDao.softDeleteCustomer(customer.id);
    await payments.moveNext();
    await activity.moveNext();
    expect(payments.current, 0);
    expect(activity.current, isEmpty);
  });
}
