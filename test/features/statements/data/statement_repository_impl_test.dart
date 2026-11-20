import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/date_service.dart';
import 'package:daftariapp/features/statements/data/repositories/statement_repository_impl.dart';
import 'package:daftariapp/features/statements/domain/entities/customer_statement_entity.dart';
import 'package:daftariapp/features/statements/domain/entities/statement_date_range.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class FixedDates implements DateService {
  @override
  DateTime now() => DateTime(2026, 11, 20, 12);
}

class MockTransactionDao extends Mock implements TransactionDao {}

class FailingCustomerDao extends CustomerDao {
  FailingCustomerDao(super.db);

  @override
  Future<Customer?> getCustomerById(String id, {bool includeDeleted = false}) =>
      throw const DatabaseException();
}

void main() {
  late AppDatabase database;
  late StatementRepositoryImpl repository;
  late Customer customer;
  late List<String> logs;
  late ErrorHandler errors;

  setUp(() async {
    logs = [];
    errors = ErrorHandler(AppLogger(output: logs.add));
    database = AppDatabase(NativeDatabase.memory());
    customer = await database.customerDao.createCustomer(
      name: 'Private customer',
      phone: '01012345678',
    );
    repository = StatementRepositoryImpl(
      database.customerDao,
      database.transactionDao,
      FixedDates(),
      errors,
    );
  });
  tearDown(() => database.close());

  test('empty active customer produces an offline zero statement', () async {
    final statement = (await repository.getCustomerStatement(customer.id))
        .getOrElse((_) => throw StateError('failure'))!;
    expect(statement.customer.id, customer.id);
    expect(statement.customer.phone, '01012345678');
    expect(statement.entries, isEmpty);
    expect(statement.balancePiasters, 0);
    expect(statement.generatedAt, FixedDates().now());
  });

  test('missing and deleted customers return null', () async {
    expect(
      await repository.getCustomerStatement('missing'),
      const Right<AppFailure, CustomerStatementEntity?>(null),
    );
    await database.customerDao.softDeleteCustomer(customer.id);
    expect(
      await repository.getCustomerStatement(customer.id),
      const Right<AppFailure, CustomerStatementEntity?>(null),
    );
  });

  test(
    'active ledger excludes deletions and other customers, newest first',
    () async {
      Future<TransactionRecord> add(
        int amount,
        DateTime date, {
        String type = TransactionTypes.credit,
        String? id,
      }) => database.transactionDao.createTransaction(
        customerId: id ?? customer.id,
        type: type,
        amountPiasters: amount,
        transactionDate: date,
      );
      await add(10001, DateTime(2026, 9, 1));
      final payment = await add(
        201,
        DateTime(2026, 11, 10),
        type: TransactionTypes.payment,
      );
      final credit = await add(303, DateTime(2026, 11, 20));
      final deleted = await add(99999, DateTime(2026, 11, 19));
      await database.transactionDao.softDeleteTransaction(deleted.id);
      final other = await database.customerDao.createCustomer(name: 'Other');
      await add(50000, DateTime(2026, 11, 20), id: other.id);

      final statement = (await repository.getCustomerStatement(
        customer.id,
        range: StatementDateRange.thisMonth,
      )).getOrElse((_) => throw StateError('failure'))!;
      expect(statement.entries.map((entry) => entry.id), [
        credit.id,
        payment.id,
      ]);
      expect(statement.balancePiasters, 10103);
      expect(statement.customer.balancePiasters, 10103);
      expect(statement.periodCreditPiasters, 303);
      expect(statement.periodPaymentPiasters, 201);
      expect(logs, isEmpty);
    },
  );

  test('transaction DAO failures map to safe database failures', () async {
    final dao = MockTransactionDao();
    when(() => dao.getCustomerTransactions(customer.id))
        .thenThrow(const DatabaseException());
    final broken = StatementRepositoryImpl(
      database.customerDao,
      dao,
      FixedDates(),
      errors,
    );
    expect(
      await broken.getCustomerStatement(customer.id),
      const Left<AppFailure, CustomerStatementEntity?>(
        AppFailure(AppErrorCode.database),
      ),
    );
  });

  test(
    'unexpected errors expose no private data in logs or failures',
    () async {
      final dao = MockTransactionDao();
      when(() => dao.getCustomerTransactions(customer.id))
          .thenThrow(StateError('Private customer 01012345678 12345'));
      final broken = StatementRepositoryImpl(
        database.customerDao,
        dao,
        FixedDates(),
        errors,
      );
      expect(
        await broken.getCustomerStatement(customer.id),
        const Left<AppFailure, CustomerStatementEntity?>(
          AppFailure(AppErrorCode.unexpected),
        ),
      );
      expect(logs, [AppErrorCode.unexpected.code]);
    },
  );

  test('customer DAO failure maps to database failure', () async {
    final broken = StatementRepositoryImpl(
      FailingCustomerDao(database),
      database.transactionDao,
      FixedDates(),
      errors,
    );
    expect(
      await broken.getCustomerStatement(customer.id),
      const Left<AppFailure, CustomerStatementEntity?>(
        AppFailure(AppErrorCode.database),
      ),
    );
  });
}
