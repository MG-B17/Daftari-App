import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/statements/domain/entities/customer_statement_entity.dart';
import 'package:daftariapp/features/statements/domain/entities/statement_date_range.dart';
import 'package:daftariapp/features/statements/domain/repositories/statement_repository.dart';
import 'package:daftariapp/features/statements/domain/usecases/get_customer_statement_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'statement_fixtures.dart';

class MockStatementRepository extends Mock implements StatementRepository {}

void main() {
  late MockStatementRepository repository;
  late GetCustomerStatementUseCase useCase;

  setUp(() {
    repository = MockStatementRepository();
    useCase = GetCustomerStatementUseCase(repository);
  });

  test(
    'passes customer ID and defaults to the complete ledger range',
    () async {
      final statement = statementFixture();
      when(() => repository.getCustomerStatement('c1'))
          .thenAnswer((_) async => Right(statement));
      expect(
        await useCase('c1'),
        Right<AppFailure, CustomerStatementEntity?>(statement),
      );
      verify(() => repository.getCustomerStatement('c1')).called(1);
      verifyNoMoreInteractions(repository);
    },
  );

  test('passes selected date range unchanged', () async {
    final range = StatementDateRange.custom(
      start: DateTime(2026, 11, 1),
      end: statementNow,
    );
    final statement = statementFixture(range: range);
    when(() => repository.getCustomerStatement('c1', range: range))
        .thenAnswer((_) async => Right(statement));
    expect(
      await useCase('c1', range: range),
      Right<AppFailure, CustomerStatementEntity?>(statement),
    );
    verify(() => repository.getCustomerStatement('c1', range: range)).called(1);
  });

  test('preserves null for a missing or deleted customer', () async {
    when(() => repository.getCustomerStatement('missing'))
        .thenAnswer((_) async => const Right(null));
    expect(
      await useCase('missing'),
      const Right<AppFailure, CustomerStatementEntity?>(null),
    );
  });

  test('propagates safe repository failure', () async {
    const failure = AppFailure(AppErrorCode.database);
    when(() => repository.getCustomerStatement('c1'))
        .thenAnswer((_) async => const Left(failure));
    expect(
      await useCase('c1'),
      const Left<AppFailure, CustomerStatementEntity?>(failure),
    );
  });
}
