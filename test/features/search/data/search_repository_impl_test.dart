import 'dart:async';

import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/features/search/data/repositories/search_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCustomerDao extends Mock implements CustomerDao {}

void main() {
  late AppDatabase database;
  late ErrorHandler errorHandler;
  late SearchRepositoryImpl repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    errorHandler = ErrorHandler(
      AppLogger(output: (_) {}, enableCrashReporting: false),
    );
    repository = SearchRepositoryImpl(database.customerDao, errorHandler);
  });

  tearDown(() => database.close());

  test('streams active customers sorted by name with derived balances and hides deleted', () async {
    final second = await database.customerDao.createCustomer(
      name: 'Ziad',
      phone: '01122223333',
    );
    final first = await database.customerDao.createCustomer(
      name: 'ahmed',
      phone: '01011112222',
    );
    final deleted = await database.customerDao.createCustomer(
      name: 'Deleted Customer',
      phone: '01299998888',
    );
    await database.customerDao.softDeleteCustomer(deleted.id);
    await database.transactionDao.createTransaction(
      customerId: first.id,
      type: TransactionTypes.credit,
      amountPiasters: 5000,
    );
    await database.transactionDao.createTransaction(
      customerId: first.id,
      type: TransactionTypes.payment,
      amountPiasters: 1500,
    );

    final result = await repository.watchSearchableCustomers().first;
    final customers = result.getOrElse((_) => const []);
    expect(customers.map((c) => c.id).toList(), [first.id, second.id]);
    expect(customers.first.balancePiasters, 3500);
    expect(customers.last.balancePiasters, 0);
  });

  test(
    'maps stream errors into AppFailure without closing the stream',
    () async {
      final mockDao = _MockCustomerDao();
      final controller = StreamController<List<CustomerWithBalance>>();
      addTearDown(controller.close);
      when(() => mockDao.watchCustomersWithBalances())
          .thenAnswer((_) => controller.stream);

      final repo = SearchRepositoryImpl(mockDao, errorHandler);
      final events = repo.watchSearchableCustomers().take(2).toList();
      controller.addError(const DatabaseException());
      controller.add(const []);

      final results = await events;
      expect(
        results.first.fold((l) => l.errorCode, (_) => null),
        AppErrorCode.database,
      );
      expect(results.last.isRight(), isTrue);
    },
  );
}
