import 'dart:io';

import 'package:daftariapp/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;
  late File databaseFile;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'daftari_database_test_',
    );
    databaseFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}daftari.sqlite',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('data survives closing and reopening a file-backed database', () async {
    final first = AppDatabase(NativeDatabase(databaseFile));
    late String customerId;
    late String transactionId;
    try {
      final customer = await first.customerDao.createCustomer(
        name: 'Persisted Customer',
        phone: '01011112222',
      );
      customerId = customer.id;
      final transaction = await first.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 12345,
        transactionDate: DateTime(2026, 4, 1),
        note: 'phase four',
      );
      transactionId = transaction.id;
      await first.transactionDao.editTransaction(
        id: transaction.id,
        type: TransactionTypes.credit,
        amountPiasters: 13000,
        transactionDate: DateTime(2026, 4, 2),
        note: 'edited before restart',
      );
      expect(await first.customerDao.getCustomerBalance(customer.id), 13000);
    } finally {
      await first.close();
    }

    expect(await databaseFile.exists(), isTrue);

    final second = AppDatabase(NativeDatabase(databaseFile));
    try {
      final customers = await second.customerDao.getActiveCustomers();
      expect(customers, hasLength(1));
      expect(customers.single.id, customerId);
      expect(customers.single.name, 'Persisted Customer');
      expect(customers.single.localRevision, 1);

      final transaction = await second.transactionDao.getTransactionById(
        transactionId,
      );
      expect(transaction, isNotNull);
      expect(transaction!.amountPiasters, 13000);
      expect(transaction.note, 'edited before restart');
      expect(transaction.localRevision, 2);

      final logs = await second.transactionDao.getAuditLogs(transactionId);
      expect(logs, hasLength(1));
      expect(logs.single.previousAmountPiasters, 12345);

      expect(await second.customerDao.getCustomerBalance(customerId), 13000);

      final totals = await second.customerDao.getDashboardTotals();
      expect(totals.activeCustomers, 1);
      expect(totals.totalCreditPiasters, 13000);
      expect(totals.balancePiasters, 13000);

      final pragma = await second
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(pragma.data['foreign_keys'], 1);
    } finally {
      await second.close();
    }
  });

  test('soft deletions persist across restarts', () async {
    final first = AppDatabase(NativeDatabase(databaseFile));
    late String customerId;
    try {
      final customer = await first.customerDao.createCustomer(
        name: 'Deleted Later',
      );
      customerId = customer.id;
      await first.customerDao.softDeleteCustomer(customer.id);
    } finally {
      await first.close();
    }

    final second = AppDatabase(NativeDatabase(databaseFile));
    try {
      expect(await second.customerDao.getActiveCustomers(), isEmpty);
      final deleted = await second.customerDao.getCustomerById(
        customerId,
        includeDeleted: true,
      );
      expect(deleted, isNotNull);
      expect(deleted!.deletedAt, isNotNull);
      expect(deleted.localRevision, 2);
    } finally {
      await second.close();
    }
  });
}
