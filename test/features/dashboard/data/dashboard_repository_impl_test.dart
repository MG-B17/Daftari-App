import 'dart:async';

import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/services/date_service.dart';
import 'package:daftariapp/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:daftariapp/features/dashboard/domain/entities/dashboard_summary_entity.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockCustomerDao extends Mock implements CustomerDao {}

class MockTransactionDao extends Mock implements TransactionDao {}

class FixedDateService implements DateService {
  DateTime value = DateTime(2026, 11, 18, 12);
  @override
  DateTime now() => value;
}

void main() {
  late AppDatabase database;
  late DashboardRepositoryImpl repository;
  late FixedDateService dates;
  final errors = ErrorHandler(
    AppLogger(output: (_) {}, enableCrashReporting: false),
  );

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    dates = FixedDateService();
    repository = DashboardRepositoryImpl(
      database.customerDao,
      database.transactionDao,
      errors,
      dates,
    );
  });
  tearDown(() => database.close());

  Future<DashboardSummaryEntity> snapshot() async =>
      (await repository.watchDashboardSummary().first).getOrElse(
        (failure) => throw StateError(failure.code),
      );

  test('empty ledger maps to empty summary', () async {
    expect(await snapshot(), const DashboardSummaryEntity.empty());
  });

  test(
    'positive balances only, top three, recent five and exact money',
    () async {
      for (var i = 0; i < 6; i++) {
        final customer = await database.customerDao.createCustomer(
          name: 'Customer $i',
          phone: '0100000000$i',
        );
        await database.transactionDao.createTransaction(
          customerId: customer.id,
          type: TransactionTypes.credit,
          amountPiasters: (i + 1) * 101,
          transactionDate: DateTime(2026, 11, 18, i),
          note: 'Entry $i',
        );
      }
      final overpaid = await database.customerDao.createCustomer(
        name: 'Overpaid',
      );
      await database.transactionDao.createTransaction(
        customerId: overpaid.id,
        type: TransactionTypes.payment,
        amountPiasters: 5000,
        transactionDate: DateTime(2026, 11, 17),
      );
      await database.customerDao.createCustomer(name: 'Settled');
      final result = await snapshot();
      expect(result.totalOwedPiasters, 2121);
      expect(result.debtorCount, 6);
      expect(result.todayCollectionsPiasters, 0);
      expect(result.topDebtors.map((row) => row.balancePiasters), [
        606,
        505,
        404,
      ]);
      expect(result.topDebtors.first.phone, '01000000005');
      expect(result.recentActivity.length, 5);
      expect(result.recentActivity.first.customerName, 'Customer 5');
      expect(result.recentActivity.first.type, TransactionType.credit);
      expect(result.recentActivity.first.note, 'Entry 5');
    },
  );

  test('live summary updates and excludes deleted records', () async {
    final customer = await database.customerDao.createCustomer(name: 'Active');
    final stream = StreamIterator(repository.watchDashboardSummary());
    addTearDown(stream.cancel);
    Future<DashboardSummaryEntity> until(
      bool Function(DashboardSummaryEntity) matches,
    ) async {
      while (await stream.moveNext()) {
        final value = stream.current.getOrElse(
          (failure) => throw StateError(failure.code),
        );
        if (matches(value)) return value;
      }
      throw StateError('Stream ended');
    }

    await until((value) => value == const DashboardSummaryEntity.empty());
    final credit = await database.transactionDao.createTransaction(
      customerId: customer.id,
      type: TransactionTypes.credit,
      amountPiasters: 1001,
      transactionDate: dates.value,
    );
    await until(
      (value) =>
          value.totalOwedPiasters == 1001 && value.recentActivity.length == 1,
    );
    final payment = await database.transactionDao.createTransaction(
      customerId: customer.id,
      type: TransactionTypes.payment,
      amountPiasters: 203,
      transactionDate: dates.value,
    );
    await until(
      (value) =>
          value.totalOwedPiasters == 798 &&
          value.todayCollectionsPiasters == 203 &&
          value.recentActivity.length == 2,
    );
    await database.transactionDao.softDeleteTransaction(payment.id);
    await until(
      (value) =>
          value.totalOwedPiasters == 1001 &&
          value.todayCollectionsPiasters == 0 &&
          value.recentActivity.length == 1,
    );
    await database.customerDao.softDeleteCustomer(customer.id);
    await until((value) => value == const DashboardSummaryEntity.empty());
    expect(
      await database.transactionDao.getTransactionById(
        credit.id,
        includeDeleted: true,
      ),
      isNotNull,
    );
  });

  test('new subscription recalculates calendar day', () async {
    final customer = await database.customerDao.createCustomer(name: 'Active');
    await database.transactionDao.createTransaction(
      customerId: customer.id,
      type: TransactionTypes.payment,
      amountPiasters: 101,
      transactionDate: dates.value,
    );
    expect((await snapshot()).todayCollectionsPiasters, 101);
    dates.value = DateTime(2026, 11, 19);
    expect((await snapshot()).todayCollectionsPiasters, 0);
  });

  test(
    'source errors become failures, recover, and cancel all watches',
    () async {
      final customers = MockCustomerDao();
      final transactions = MockTransactionDao();
      final balances = StreamController<List<CustomerWithBalance>>();
      final activity = StreamController<List<TransactionWithCustomer>>();
      final collections = StreamController<int>();
      addTearDown(balances.close);
      addTearDown(activity.close);
      addTearDown(collections.close);
      when(() => customers.watchCustomersWithBalances())
          .thenAnswer((_) => balances.stream);
      when(() => transactions.watchRecentTransactionsWithCustomer(limit: 5))
          .thenAnswer((_) => activity.stream);
      when(
        () => transactions.watchTodayPaymentsPiasters(
          DateTime(2026, 11, 18),
          DateTime(2026, 11, 19),
        ),
      ).thenAnswer((_) => collections.stream);
      final broken = DashboardRepositoryImpl(
        customers,
        transactions,
        errors,
        dates,
      );
      final iterator = StreamIterator(broken.watchDashboardSummary());
      final first = iterator.moveNext();
      balances.add([]);
      activity.add([]);
      collections.add(0);
      await first;
      expect(
        iterator.current,
        const Right<AppFailure, DashboardSummaryEntity>(
          DashboardSummaryEntity.empty(),
        ),
      );
      for (final source in [balances, activity, collections]) {
        source.addError(const DatabaseException());
        await iterator.moveNext();
        expect(
          iterator.current,
          const Left<AppFailure, DashboardSummaryEntity>(
            AppFailure(AppErrorCode.database),
          ),
        );
      }
      balances.add([]);
      activity.add([]);
      collections.add(0);
      await iterator.moveNext();
      expect(iterator.current.isRight(), isTrue);
      await iterator.cancel();
      expect(balances.hasListener, isFalse);
      expect(activity.hasListener, isFalse);
      expect(collections.hasListener, isFalse);
    },
  );

  test('synchronous setup failure maps to a safe failure', () async {
    final customers = MockCustomerDao();
    final transactions = MockTransactionDao();
    when(() => customers.watchCustomersWithBalances())
        .thenThrow(const DatabaseException());
    final broken = DashboardRepositoryImpl(
      customers,
      transactions,
      errors,
      dates,
    );
    expect(
      await broken.watchDashboardSummary().first,
      const Left<AppFailure, DashboardSummaryEntity>(
        AppFailure(AppErrorCode.database),
      ),
    );
  });
}
