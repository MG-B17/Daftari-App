import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/utils/money_utils.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
import 'package:daftariapp/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:daftariapp/features/transactions/domain/usecases/create_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/edit_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/get_transaction_by_id_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/soft_delete_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/watch_customer_transactions_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockTransactionRepository repository;
  final date = DateTime(2020, 2, 3);
  final entity = TransactionEntity(
    id: 't1',
    customerId: 'c1',
    type: TransactionType.credit,
    amountPiasters: 123,
    transactionDate: date,
    createdAt: date,
    updatedAt: date,
    note: 'note',
  );
  const failure = AppFailure(AppErrorCode.validation);

  setUp(() => repository = MockTransactionRepository());

  test('entity has value equality across ledger fields', () {
    expect(
      entity,
      TransactionEntity(
        id: 't1',
        customerId: 'c1',
        type: TransactionType.credit,
        amountPiasters: 123,
        transactionDate: date,
        createdAt: date,
        updatedAt: date,
        note: 'note',
      ),
    );
    expect(entity.type, TransactionType.credit);
    expect(TransactionType.values, [
      TransactionType.credit,
      TransactionType.payment,
    ]);
  });

  test(
    'create and edit reject invalid amounts before repository access',
    () async {
      for (final amount in [0, -1, MoneyUtils.maxPiasters + 1]) {
        final created = await CreateTransactionUseCase(repository)(
          customerId: 'c1',
          type: TransactionType.credit,
          amountPiasters: amount,
          transactionDate: date,
        );
        final edited = await EditTransactionUseCase(repository)(
          id: 't1',
          type: TransactionType.payment,
          amountPiasters: amount,
          transactionDate: date,
        );
        expect(created, Left<AppFailure, TransactionEntity>(failure));
        expect(edited, Left<AppFailure, TransactionEntity>(failure));
      }
      verifyZeroInteractions(repository);
    },
  );

  test(
    'create passes a past date, note and maximum amount unchanged',
    () async {
      when(
        () => repository.createTransaction(
          customerId: 'c1',
          type: TransactionType.credit,
          amountPiasters: MoneyUtils.maxPiasters,
          transactionDate: date,
          note: 'note',
        ),
      ).thenAnswer((_) async => Right(entity));
      final result = await CreateTransactionUseCase(repository)(
        customerId: 'c1',
        type: TransactionType.credit,
        amountPiasters: MoneyUtils.maxPiasters,
        transactionDate: date,
        note: 'note',
      );
      expect(result, Right<AppFailure, TransactionEntity>(entity));
      verify(
        () => repository.createTransaction(
          customerId: 'c1',
          type: TransactionType.credit,
          amountPiasters: MoneyUtils.maxPiasters,
          transactionDate: date,
          note: 'note',
        ),
      ).called(1);
    },
  );

  test('edit passes minimum positive amount and propagates failure', () async {
    when(
      () => repository.editTransaction(
        id: 't1',
        type: TransactionType.payment,
        amountPiasters: 1,
        transactionDate: date,
        note: null,
      ),
    ).thenAnswer((_) async => const Left(failure));
    expect(
      await EditTransactionUseCase(repository)(
        id: 't1',
        type: TransactionType.payment,
        amountPiasters: 1,
        transactionDate: date,
      ),
      const Left<AppFailure, TransactionEntity>(failure),
    );
    verify(
      () => repository.editTransaction(
        id: 't1',
        type: TransactionType.payment,
        amountPiasters: 1,
        transactionDate: date,
        note: null,
      ),
    ).called(1);
  });

  test('watch forwards successive values and failures', () async {
    final values = <Either<AppFailure, List<TransactionEntity>>>[
      Right([entity]),
      const Left(failure),
      const Right([]),
    ];
    when(() => repository.watchCustomerTransactions('c1'))
        .thenAnswer((_) => Stream.fromIterable(values));
    expect(
      await WatchCustomerTransactionsUseCase(repository)('c1').toList(),
      values,
    );
    verify(() => repository.watchCustomerTransactions('c1')).called(1);
  });

  test(
    'lookup and soft delete forward results without changing them',
    () async {
      when(() => repository.getTransactionById('missing'))
          .thenAnswer((_) async => const Right(null));
      when(() => repository.softDeleteTransaction('t1'))
          .thenAnswer((_) async => const Right(false));
      expect(
        await GetTransactionByIdUseCase(repository)('missing'),
        const Right<AppFailure, TransactionEntity?>(null),
      );
      expect(
        await SoftDeleteTransactionUseCase(repository)('t1'),
        const Right<AppFailure, bool>(false),
      );
      verify(() => repository.getTransactionById('missing')).called(1);
      verify(() => repository.softDeleteTransaction('t1')).called(1);
    },
  );
}
