import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CustomerDao customers;
  late TransactionDao transactions;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    customers = database.customerDao;
    transactions = database.transactionDao;
  });

  tearDown(() => database.close());

  test('creates and reads a customer with backup metadata', () async {
    final created = await customers.createCustomer(
      name: '  Ahmed Ali ',
      phone: ' 01000000000 ',
      notes: ' VIP ',
    );

    expect(created.id, isNotEmpty);
    expect(created.name, 'Ahmed Ali');
    expect(created.phone, '01000000000');
    expect(created.notes, 'VIP');
    expect(created.localRevision, 1);
    expect(created.deletedAt, isNull);
    expect(created.syncedAt, isNull);
    expect(await customers.getCustomerById(created.id), created);
  });

  test('rejects a blank customer name', () async {
    await expectLater(
      customers.createCustomer(name: '   '),
      throwsA(isA<ValidationException>()),
    );
    expect(await customers.getActiveCustomers(), isEmpty);
  });

  test(
    'lists active customers alphabetically and hides soft-deleted ones',
    () async {
      final zainab = await customers.createCustomer(name: 'Zainab');
      final ahmed = await customers.createCustomer(name: 'Ahmed');
      final mona = await customers.createCustomer(name: 'Mona');

      expect((await customers.getActiveCustomers()).map((c) => c.name), [
        'Ahmed',
        'Mona',
        'Zainab',
      ]);
      expect(await customers.watchActiveCustomers().first, hasLength(3));

      expect(await customers.softDeleteCustomer(mona.id), isTrue);
      expect((await customers.getActiveCustomers()).map((c) => c.name), [
        'Ahmed',
        'Zainab',
      ]);
      expect(await customers.getCustomerById(mona.id), isNull);
      expect(
        await customers.getCustomerById(mona.id, includeDeleted: true),
        isNotNull,
      );
      expect(zainab.deletedAt, isNull);
      expect(ahmed.deletedAt, isNull);
    },
  );

  test('searches active customers by name and phone', () async {
    await customers.createCustomer(name: 'Mona Hassan', phone: '01111111111');
    await customers.createCustomer(name: 'Ahmed Ali', phone: '01222222222');
    final deleted = await customers.createCustomer(
      name: 'Mona Deleted',
      phone: '01333333333',
    );
    await customers.softDeleteCustomer(deleted.id);

    expect((await customers.searchCustomers('mona')).map((c) => c.name), [
      'Mona Hassan',
    ]);
    expect((await customers.searchCustomers('012')).map((c) => c.name), [
      'Ahmed Ali',
    ]);
    expect((await customers.searchCustomers('  ')).map((c) => c.name), [
      'Ahmed Ali',
      'Mona Hassan',
    ]);
    expect(await customers.watchSearchCustomers('mona').first, hasLength(1));
  });

  test('update bumps localRevision and only edits active customers', () async {
    final created = await customers.createCustomer(
      name: 'Old Name',
      phone: '010',
    );

    expect(
      await customers.updateCustomer(
        id: created.id,
        name: ' New Name ',
        phone: '011',
        notes: 'updated',
      ),
      isTrue,
    );

    final updated = await customers.getCustomerById(created.id);
    expect(updated!.name, 'New Name');
    expect(updated.phone, '011');
    expect(updated.notes, 'updated');
    expect(updated.localRevision, created.localRevision + 1);
    expect(updated.updatedAt.isBefore(created.updatedAt), isFalse);

    await customers.softDeleteCustomer(created.id);
    expect(
      await customers.updateCustomer(id: created.id, name: 'Again'),
      isFalse,
    );
    final deleted = await customers.getCustomerById(
      created.id,
      includeDeleted: true,
    );
    expect(deleted!.name, 'New Name');
    expect(deleted.localRevision, created.localRevision + 2);
  });

  test('soft delete is idempotent and preserves revision history', () async {
    final created = await customers.createCustomer(name: 'Delete Me');

    expect(await customers.softDeleteCustomer(created.id), isTrue);
    final deleted = await customers.getCustomerById(
      created.id,
      includeDeleted: true,
    );
    expect(deleted!.deletedAt, isNotNull);
    expect(deleted.updatedAt, deleted.deletedAt);
    expect(deleted.localRevision, created.localRevision + 1);

    expect(await customers.softDeleteCustomer(created.id), isFalse);
    final unchanged = await customers.getCustomerById(
      created.id,
      includeDeleted: true,
    );
    expect(unchanged!.localRevision, deleted.localRevision);
    expect(unchanged.deletedAt, deleted.deletedAt);
  });

  test(
    'derived balance ignores soft-deleted transactions and customers',
    () async {
      final customer = await customers.createCustomer(name: 'Balanced');
      final other = await customers.createCustomer(name: 'Other');

      await transactions.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 15000,
      );
      final payment = await transactions.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.payment,
        amountPiasters: 7000,
      );
      await transactions.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 5000,
      );

      expect(await customers.getCustomerBalance(customer.id), 13000);
      expect(await customers.watchCustomerBalance(customer.id).first, 13000);

      await transactions.softDeleteTransaction(payment.id);
      expect(await customers.getCustomerBalance(customer.id), 20000);

      await transactions.createTransaction(
        customerId: other.id,
        type: TransactionTypes.credit,
        amountPiasters: 999,
      );
      await customers.softDeleteCustomer(other.id);
      expect(await customers.getCustomerBalance(other.id), 0);
      expect(await customers.getCustomerBalance('missing'), 0);
    },
  );

  test(
    'dashboard totals only cover active customers and transactions',
    () async {
      expect(
        await customers.getDashboardTotals(),
        const DashboardTotals.empty(),
      );

      final first = await customers.createCustomer(name: 'First');
      final second = await customers.createCustomer(name: 'Second');
      final third = await customers.createCustomer(name: 'Third');

      await transactions.createTransaction(
        customerId: first.id,
        type: TransactionTypes.credit,
        amountPiasters: 12000,
      );
      await transactions.createTransaction(
        customerId: first.id,
        type: TransactionTypes.payment,
        amountPiasters: 2000,
      );
      await transactions.createTransaction(
        customerId: second.id,
        type: TransactionTypes.credit,
        amountPiasters: 4000,
      );
      final deletedTransaction = await transactions.createTransaction(
        customerId: second.id,
        type: TransactionTypes.credit,
        amountPiasters: 500,
      );
      await transactions.softDeleteTransaction(deletedTransaction.id);

      await transactions.createTransaction(
        customerId: third.id,
        type: TransactionTypes.credit,
        amountPiasters: 8000,
      );
      await customers.softDeleteCustomer(third.id);

      final totals = await customers.getDashboardTotals();
      expect(totals.activeCustomers, 2);
      expect(totals.totalCreditPiasters, 16000);
      expect(totals.totalPaymentPiasters, 2000);
      expect(totals.balancePiasters, 14000);
      expect(await customers.watchDashboardTotals().first, totals);
    },
  );
}
