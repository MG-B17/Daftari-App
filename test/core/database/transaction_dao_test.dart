import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CustomerDao customers;
  late TransactionDao transactions;
  late Customer customer;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    customers = database.customerDao;
    transactions = database.transactionDao;
    customer = await customers.createCustomer(name: 'Ledger Customer');
  });

  tearDown(() => database.close());

  Future<TransactionRecord> addCredit(
    int amount, {
    DateTime? date,
    String? note,
    String? customerId,
  }) {
    return transactions.createTransaction(
      customerId: customerId ?? customer.id,
      type: TransactionTypes.credit,
      amountPiasters: amount,
      transactionDate: date,
      note: note,
    );
  }

  test('inserts transactions and lists them newest first', () async {
    final older = await addCredit(
      1000,
      date: DateTime(2026, 1, 1),
      note: 'january',
    );
    final newer = await addCredit(2000, date: DateTime(2026, 3, 1));
    final middle = await addCredit(1500, date: DateTime(2026, 2, 1));

    expect(older.type, TransactionTypes.credit);
    expect(older.amountPiasters, 1000);
    expect(older.note, 'january');
    expect(older.localRevision, 1);

    final listed = await transactions.getCustomerTransactions(customer.id);
    expect(listed.map((row) => row.id), [newer.id, middle.id, older.id]);
    expect(
      (await transactions.watchCustomerTransactions(customer.id).first).map(
        (row) => row.id,
      ),
      [newer.id, middle.id, older.id],
    );
  });

  test('rejects invalid type and non-positive amounts', () async {
    await expectLater(addCredit(0), throwsA(isA<ValidationException>()));
    await expectLater(
      transactions.createTransaction(
        customerId: customer.id,
        type: 'transfer',
        amountPiasters: 100,
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(await transactions.getCustomerTransactions(customer.id), isEmpty);
  });

  test('rejects transactions for a soft-deleted customer', () async {
    final deleted = await customers.createCustomer(name: 'Gone');
    await customers.softDeleteCustomer(deleted.id);

    await expectLater(
      addCredit(1000, customerId: deleted.id),
      throwsA(isA<ValidationException>()),
    );
    expect(await transactions.getCustomerTransactions(deleted.id), isEmpty);
    expect(await transactions.getRecentTransactions(), isEmpty);
  });

  test('hides transactions of soft-deleted customers', () async {
    final other = await customers.createCustomer(name: 'Deleted Customer');
    final kept = await addCredit(1000);
    final hidden = await addCredit(2000, customerId: other.id);

    await customers.softDeleteCustomer(other.id);

    expect(
      (await transactions.getCustomerTransactions(customer.id))
          .map((row) => row.id),
      [kept.id],
    );
    expect(await transactions.getCustomerTransactions(other.id), isEmpty);
    expect(await transactions.getTransactionById(hidden.id), isNull);
    expect(
      await transactions.getTransactionById(hidden.id, includeDeleted: true),
      isNotNull,
    );
    expect((await transactions.getRecentTransactions()).map((row) => row.id), [
      kept.id,
    ]);
    expect(
      (await transactions.watchRecentTransactions().first).map((row) => row.id),
      [kept.id],
    );
  });

  test('hides soft-deleted transactions and limits recent activity', () async {
    final first = await addCredit(1000, date: DateTime(2026, 1, 1));
    final second = await addCredit(2000, date: DateTime(2026, 1, 2));
    final third = await addCredit(3000, date: DateTime(2026, 1, 3));

    await transactions.softDeleteTransaction(second.id);

    final recent = await transactions.getRecentTransactions(limit: 2);
    expect(recent.map((row) => row.id), [third.id, first.id]);
    expect(await transactions.getTransactionById(second.id), isNull);
    expect(
      await transactions.getTransactionById(second.id, includeDeleted: true),
      isNotNull,
    );
  });

  test('editTransaction appends audit values and bumps revision', () async {
    final created = await addCredit(
      1000,
      date: DateTime(2026, 1, 1),
      note: 'before',
    );

    final edited = await transactions.editTransaction(
      id: created.id,
      type: TransactionTypes.payment,
      amountPiasters: 2500,
      transactionDate: DateTime(2026, 2, 2),
      note: 'after',
    );

    expect(edited.type, TransactionTypes.payment);
    expect(edited.amountPiasters, 2500);
    expect(edited.note, 'after');
    expect(edited.transactionDate, DateTime(2026, 2, 2));
    expect(edited.localRevision, created.localRevision + 1);

    final logs = await transactions.getAuditLogs(created.id);
    expect(logs, hasLength(1));
    final log = logs.single;
    expect(log.action, TransactionAuditActions.edit);
    expect(log.transactionId, created.id);
    expect(log.previousType, TransactionTypes.credit);
    expect(log.previousAmountPiasters, 1000);
    expect(log.previousNote, 'before');
    expect(log.previousTransactionDate, DateTime(2026, 1, 1));
    expect(log.localRevision, 1);
    expect(log.syncedAt, isNull);

    expect(await customers.getCustomerBalance(customer.id), -2500);
  });

  test('softDeleteTransaction appends audit values exactly once', () async {
    final created = await addCredit(4000, note: 'to delete');

    expect(await transactions.softDeleteTransaction(created.id), isTrue);

    final deleted = await transactions.getTransactionById(
      created.id,
      includeDeleted: true,
    );
    expect(deleted!.deletedAt, isNotNull);
    expect(deleted.updatedAt, deleted.deletedAt);
    expect(deleted.localRevision, created.localRevision + 1);

    final logs = await transactions.getAuditLogs(created.id);
    expect(logs, hasLength(1));
    expect(logs.single.action, TransactionAuditActions.delete);
    expect(logs.single.previousAmountPiasters, 4000);
    expect(logs.single.previousNote, 'to delete');

    expect(await transactions.softDeleteTransaction(created.id), isFalse);
    expect(await transactions.getAuditLogs(created.id), hasLength(1));
  });

  test('failed edit rolls back the audit log and the transaction', () async {
    final created = await addCredit(1000, note: 'unchanged');

    await database.customStatement('''
      CREATE TRIGGER fail_transaction_update
      BEFORE UPDATE ON transactions
      BEGIN
        SELECT RAISE(ABORT, 'blocked');
      END;
    ''');

    await expectLater(
      transactions.editTransaction(
        id: created.id,
        type: TransactionTypes.payment,
        amountPiasters: 9999,
        transactionDate: DateTime(2027, 1, 1),
      ),
      throwsA(isA<DatabaseException>()),
    );

    expect(await transactions.getAuditLogs(created.id), isEmpty);
    final unchanged = await transactions.getTransactionById(created.id);
    expect(unchanged!.amountPiasters, 1000);
    expect(unchanged.type, TransactionTypes.credit);
    expect(unchanged.note, 'unchanged');
    expect(unchanged.localRevision, created.localRevision);
  });

  test('editing a missing or deleted transaction is rejected', () async {
    await expectLater(
      transactions.editTransaction(
        id: 'missing',
        type: TransactionTypes.credit,
        amountPiasters: 100,
        transactionDate: DateTime(2026, 1, 1),
      ),
      throwsA(isA<ValidationException>()),
    );

    final created = await addCredit(1000);
    await transactions.softDeleteTransaction(created.id);
    await expectLater(
      transactions.editTransaction(
        id: created.id,
        type: TransactionTypes.credit,
        amountPiasters: 2000,
        transactionDate: DateTime(2026, 1, 1),
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(await transactions.getAuditLogs(created.id), hasLength(1));
  });

  test('audit logs are append-only and scoped per transaction', () async {
    final first = await addCredit(1000);
    final second = await addCredit(2000);

    await transactions.editTransaction(
      id: first.id,
      type: TransactionTypes.credit,
      amountPiasters: 1200,
      transactionDate: DateTime(2026, 1, 1),
    );
    await transactions.editTransaction(
      id: first.id,
      type: TransactionTypes.payment,
      amountPiasters: 300,
      transactionDate: DateTime(2026, 1, 2),
    );
    await transactions.softDeleteTransaction(second.id);

    final firstLogs = await transactions.getAuditLogs(first.id);
    expect(firstLogs, hasLength(2));
    expect(
      firstLogs.map((log) => log.action),
      everyElement(TransactionAuditActions.edit),
    );
    expect(
      firstLogs.map((log) => log.previousAmountPiasters),
      containsAll([1000, 1200]),
    );
    expect(await transactions.getAuditLogs(second.id), hasLength(1));
    expect(firstLogs.every((log) => log.transactionId == first.id), isTrue);
  });
}
