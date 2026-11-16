import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  Future<Set<Object?>> schemaNames(String type) async {
    final rows = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = '$type'")
        .get();
    return rows.map((row) => row.data['name']).toSet();
  }

  test('onCreate creates every table and index at schema version 1', () async {
    expect(database.schemaVersion, 1);
    expect(
      await schemaNames('table'),
      containsAll(['customers', 'transactions', 'transaction_audit_logs']),
    );
    expect(
      await schemaNames('index'),
      containsAll([
        'idx_customers_deleted_at',
        'idx_customers_name',
        'idx_transactions_customer_id',
        'idx_transactions_deleted_at',
        'idx_transactions_transaction_date',
        'idx_transactions_customer_deleted',
        'idx_transaction_audit_logs_transaction_id',
      ]),
    );
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data['user_version'], 1);
  });

  test(
    'beforeOpen enables foreign key enforcement on every connection',
    () async {
      final pragma = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(pragma.data['foreign_keys'], 1);
    },
  );

  test('foreign key violations surface as DatabaseException', () async {
    await expectLater(
      database.transactionDao.createTransaction(
        customerId: 'missing-customer',
        type: TransactionTypes.credit,
        amountPiasters: 500,
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('foreign keys restrict deleting a customer with transactions', () async {
    final customer = await database.customerDao.createCustomer(name: 'Samir');
    await database.transactionDao.createTransaction(
      customerId: customer.id,
      type: TransactionTypes.credit,
      amountPiasters: 900,
    );

    await expectLater(
      database.customStatement('DELETE FROM customers WHERE id = ?', [
        customer.id,
      ]),
      throwsA(isA<SqliteException>()),
    );
  });

  test('CHECK constraints reject invalid transaction rows', () async {
    final customer = await database.customerDao.createCustomer(name: 'Hala');
    final now = DateTime.now();

    await expectLater(
      database
          .into(database.transactions)
          .insert(
            TransactionsCompanion(
              id: const Value('invalid-amount'),
              customerId: Value(customer.id),
              type: const Value(TransactionTypes.credit),
              amountPiasters: const Value(0),
              transactionDate: Value(now),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );

    await expectLater(
      database
          .into(database.transactions)
          .insert(
            TransactionsCompanion(
              id: const Value('invalid-type'),
              customerId: Value(customer.id),
              type: const Value('transfer'),
              amountPiasters: const Value(100),
              transactionDate: Value(now),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );

    expect(
      await database.transactionDao.getCustomerTransactions(customer.id),
      isEmpty,
    );
  });
}
