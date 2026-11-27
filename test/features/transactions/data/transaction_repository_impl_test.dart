import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/core/utils/money_utils.dart';
import 'package:daftariapp/features/transactions/data/mappers/transaction_mapper.dart';
import 'package:daftariapp/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionDao extends Mock implements TransactionDao {}

void main() {
  late AppDatabase database;
  late TransactionRepositoryImpl repository;
  late Customer customer;
  final errors = ErrorHandler(
    AppLogger(output: (_) {}, enableCrashReporting: false),
  );

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    customer = await database.customerDao.createCustomer(name: 'Customer');
    repository = TransactionRepositoryImpl(database.transactionDao, errors);
  });
  tearDown(() => database.close());

  test('create, watch, edit and delete preserve ledger and audit', () async {
    final past = DateTime(2020, 1, 3);
    final created = (await repository.createTransaction(
      customerId: customer.id,
      type: TransactionType.credit,
      amountPiasters: 12345,
      transactionDate: past,
      note: '  goods  ',
    )).getOrElse((failure) => throw StateError(failure.code));
    expect(created.type, TransactionType.credit);
    expect(created.amountPiasters, 12345);
    expect(created.transactionDate, past);
    expect(created.note, 'goods');
    expect(
      (await repository.watchCustomerTransactions(customer.id).first).getOrElse(
        (failure) => throw StateError(failure.code),
      ),
      [created],
    );
    expect(
      (await repository.getTransactionById(created.id))
          .getOrElse((failure) => throw StateError(failure.code)),
      created,
    );
    final edited = (await repository.editTransaction(
      id: created.id,
      type: TransactionType.payment,
      amountPiasters: 500,
      transactionDate: DateTime(2019, 1, 1),
    )).getOrElse((failure) => throw StateError(failure.code));
    expect(edited.type, TransactionType.payment);
    expect(edited.note, isNull);
    expect(edited.transactionDate, DateTime(2019, 1, 1));
    expect((await database.transactionDao.getAuditLogs(created.id)).length, 1);
    expect(
      await repository.softDeleteTransaction(created.id),
      const Right<AppFailure, bool>(true),
    );
    expect(
      await repository.softDeleteTransaction(created.id),
      const Right<AppFailure, bool>(false),
    );
    expect((await database.transactionDao.getAuditLogs(created.id)).length, 2);
    expect(
      await repository.getTransactionById(created.id),
      const Right<AppFailure, TransactionEntity?>(null),
    );
    expect(
      (await repository.watchCustomerTransactions(customer.id).first).getOrElse(
        (_) => throw StateError('failure'),
      ),
      isEmpty,
    );
  });

  test('invalid amounts and missing records map to safe failures', () async {
    for (final amount in [0, -1, MoneyUtils.maxPiasters + 1]) {
      final result = await repository.createTransaction(
        customerId: customer.id,
        type: TransactionType.credit,
        amountPiasters: amount,
        transactionDate: DateTime(2020),
      );
      expect(
        result,
        const Left<AppFailure, TransactionEntity>(
          AppFailure(AppErrorCode.validation),
        ),
      );
      final edit = await repository.editTransaction(
        id: 'missing',
        type: TransactionType.credit,
        amountPiasters: amount,
        transactionDate: DateTime(2020),
      );
      expect(
        edit,
        const Left<AppFailure, TransactionEntity>(
          AppFailure(AppErrorCode.validation),
        ),
      );
    }
    expect(
      await repository.editTransaction(
        id: 'missing',
        type: TransactionType.credit,
        amountPiasters: 1,
        transactionDate: DateTime(2020),
      ),
      const Left<AppFailure, TransactionEntity>(
        AppFailure(AppErrorCode.validation),
      ),
    );
    expect(
      await repository.getTransactionById('missing'),
      const Right<AppFailure, TransactionEntity?>(null),
    );
  });

  test('mapper rejects unknown types without misclassifying data', () async {
    final record = await database.transactionDao.createTransaction(
      customerId: customer.id,
      type: TransactionTypes.credit,
      amountPiasters: 1,
    );
    expect(
      () => TransactionMapper.toEntity(record.copyWith(type: 'invalid')),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      TransactionMapper.toDatabaseType(TransactionType.payment),
      TransactionTypes.payment,
    );
  });

  test('DAO and stream failures are mapped to safe failures', () async {
    final dao = MockTransactionDao();
    final broken = TransactionRepositoryImpl(dao, errors);
    when(() => dao.getTransactionById('x'))
        .thenThrow(const DatabaseException());
    when(() => dao.watchCustomerTransactions('x'))
        .thenAnswer((_) => Stream.error(const DatabaseException()));
    expect(
      await broken.getTransactionById('x'),
      const Left<AppFailure, TransactionEntity?>(
        AppFailure(AppErrorCode.database),
      ),
    );
    expect(
      await broken.watchCustomerTransactions('x').first,
      const Left<AppFailure, List<TransactionEntity>>(
        AppFailure(AppErrorCode.database),
      ),
    );
  });
}
