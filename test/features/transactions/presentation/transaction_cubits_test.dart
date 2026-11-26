import 'dart:async';

import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/customers/domain/repositories/customer_repository.dart';
import 'package:daftariapp/features/customers/domain/usecases/watch_customers_usecase.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
import 'package:daftariapp/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:daftariapp/features/transactions/domain/usecases/create_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/edit_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/get_transaction_by_id_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/soft_delete_transaction_usecase.dart';
import 'package:daftariapp/features/transactions/domain/usecases/watch_customer_transactions_usecase.dart';
import 'package:daftariapp/features/transactions/presentation/cubit/customer_transactions_cubit.dart';
import 'package:daftariapp/features/transactions/presentation/cubit/transaction_form_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../../customer_test_setup.dart';

class _ControlledCustomerRepo implements CustomerRepository {
  final controller =
      StreamController<Either<AppFailure, List<CustomerEntity>>>.broadcast();

  @override
  Stream<Either<AppFailure, List<CustomerEntity>>> watchCustomers({
    String query = '',
    CustomerFilter filter = CustomerFilter.all,
    CustomerSort sort = CustomerSort.nameAsc,
  }) => controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Future<void> dispose() => controller.close();
}

class _ControlledTransactionRepo implements TransactionRepository {
  final entries =
      StreamController<Either<AppFailure, List<TransactionEntity>>>.broadcast();
  Completer<Either<AppFailure, TransactionEntity>>? pendingCreate;
  Completer<Either<AppFailure, TransactionEntity>>? pendingEdit;
  Completer<Either<AppFailure, bool>>? pendingDelete;
  Either<AppFailure, TransactionEntity>? createResult;
  Either<AppFailure, TransactionEntity>? editResult;
  Either<AppFailure, bool> deleteResult = const Right(true);
  int createCalls = 0;
  int editCalls = 0;
  int deleteCalls = 0;

  @override
  Stream<Either<AppFailure, List<TransactionEntity>>> watchCustomerTransactions(
    String customerId,
  ) => entries.stream;

  @override
  Future<Either<AppFailure, TransactionEntity?>> getTransactionById(
    String id,
  ) async => const Right(null);

  @override
  Future<Either<AppFailure, TransactionEntity>> createTransaction({
    required String customerId,
    required TransactionType type,
    required int amountPiasters,
    required DateTime transactionDate,
    String? note,
  }) async {
    createCalls++;
    if (pendingCreate != null) return pendingCreate!.future;
    return createResult ??
        Right(
          TransactionEntity(
            id: 'tx-1',
            customerId: customerId,
            type: type,
            amountPiasters: amountPiasters,
            transactionDate: transactionDate,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            note: note,
          ),
        );
  }

  @override
  Future<Either<AppFailure, TransactionEntity>> editTransaction({
    required String id,
    required TransactionType type,
    required int amountPiasters,
    required DateTime transactionDate,
    String? note,
  }) async {
    editCalls++;
    if (pendingEdit != null) return pendingEdit!.future;
    return editResult ??
        Right(
          TransactionEntity(
            id: id,
            customerId: 'c1',
            type: type,
            amountPiasters: amountPiasters,
            transactionDate: transactionDate,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            note: note,
          ),
        );
  }

  @override
  Future<Either<AppFailure, bool>> softDeleteTransaction(String id) async {
    deleteCalls++;
    if (pendingDelete != null) return pendingDelete!.future;
    return deleteResult;
  }

  Future<void> dispose() => entries.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() async => db = await setupCustomerTests(seed: false));
  tearDown(() => sl.reset());

  test(
    'create, edit and delete use live data and preserve the past date',
    () async {
      final customer = await db.customerDao.createCustomer(name: 'Test');
      final form = sl<TransactionFormCubit>();
      final customersReady = form.stream.firstWhere(
        (state) => state.customers.isNotEmpty,
      );
      await form.load(null);
      await customersReady.timeout(const Duration(seconds: 5));
      final date = DateTime(2021, 4, 5);
      await form.save(
        customerId: customer.id,
        type: TransactionType.credit,
        amount: '12.34',
        date: date,
        note: 'goods',
      );
      expect(form.state.saved, isTrue);
      expect(form.state.savedType, TransactionType.credit);
      expect(form.state.submissionId, 1);
      final created = (await db.transactionDao.getCustomerTransactions(
        customer.id,
      )).single;
      expect(created.amountPiasters, 1234);
      expect(created.transactionDate, date);
      final edit = sl<TransactionFormCubit>();
      final editReady = edit.stream.firstWhere(
        (state) => state.customers.isNotEmpty && state.transaction != null,
      );
      await edit.load(created.id);
      await editReady.timeout(const Duration(seconds: 5));
      await edit.save(
        customerId: customer.id,
        type: TransactionType.payment,
        amount: '5',
        date: date,
      );
      expect(edit.state.saved, isTrue);
      expect(edit.state.savedType, TransactionType.payment);
      expect(edit.state.submissionId, 1);
      expect((await db.transactionDao.getAuditLogs(created.id)).length, 1);
      final history = sl<CustomerTransactionsCubit>();
      final historyReady = history.stream.firstWhere(
        (state) => !state.loading && state.entries.isNotEmpty,
      );
      await history.load(customer.id);
      expect(
        (await historyReady.timeout(const Duration(seconds: 5)))
            .entries
            .single
            .type,
        TransactionType.payment,
      );
      expect(history.state.runningBalances, {created.id: BigInt.from(-500)});
      await history.delete(created.id);
      expect(history.state.deleted, isTrue);
      expect(history.state.deleteSubmissionId, 1);
      expect((await db.transactionDao.getAuditLogs(created.id)).length, 2);
      expect(await db.transactionDao.getTransactionById(created.id), isNull);
      await history.close();
      await edit.close();
      await form.close();
    },
  );

  test('missing edit never creates a new transaction', () async {
    final customer = await db.customerDao.createCustomer(name: 'Test');
    final form = sl<TransactionFormCubit>();
    final customersReady = form.stream.firstWhere(
      (state) => state.customers.isNotEmpty,
    );
    await form.load('missing');
    await customersReady.timeout(const Duration(seconds: 5));
    await form.save(
      customerId: customer.id,
      type: TransactionType.credit,
      amount: '10',
      date: DateTime(2020),
    );
    expect(form.state.saved, isFalse);
    expect(form.state.submissionStatus, TransactionFormSubmissionStatus.failed);
    expect(
      await db.transactionDao.getCustomerTransactions(customer.id),
      isEmpty,
    );
    await form.close();
  });

  test(
    'running balances follow chronological credit and payment entries',
    () async {
      final customer = await db.customerDao.createCustomer(name: 'Balances');
      final first = await db.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.credit,
        amountPiasters: 10000,
        transactionDate: DateTime(2021, 1, 1),
      );
      final second = await db.transactionDao.createTransaction(
        customerId: customer.id,
        type: TransactionTypes.payment,
        amountPiasters: 3000,
        transactionDate: DateTime(2021, 1, 2),
      );
      final history = sl<CustomerTransactionsCubit>();
      final ready = history.stream.firstWhere(
        (state) => state.entries.length == 2,
      );
      await history.load(customer.id);
      final state = await ready.timeout(const Duration(seconds: 5));
      expect(state.runningBalances, {
        first.id: BigInt.from(10000),
        second.id: BigInt.from(7000),
      });
      expect(() => state.runningBalances.clear(), throwsUnsupportedError);
      await history.close();
    },
  );

  test('reloading the form replaces the customer subscription', () async {
    final customer = await db.customerDao.createCustomer(name: 'Test');
    final form = sl<TransactionFormCubit>();
    final first = form.stream.firstWhere((state) => state.customers.isNotEmpty);
    await form.load(null);
    await first.timeout(const Duration(seconds: 5));
    await form.load(null).timeout(const Duration(seconds: 5));
    await form.save(
      customerId: customer.id,
      type: TransactionType.credit,
      amount: '1',
      date: DateTime(2020),
    );
    expect(form.state.saved, isTrue);
    await form.close().timeout(const Duration(seconds: 5));
  });

  test('duplicate save calls while pending run once and consecutive failures increment submissionId', () async {
    final customersRepo = _ControlledCustomerRepo();
    final txRepo = _ControlledTransactionRepo();
    addTearDown(customersRepo.dispose);
    addTearDown(txRepo.dispose);
    final cubit = TransactionFormCubit(
      WatchCustomersUseCase(customersRepo),
      GetTransactionByIdUseCase(txRepo),
      CreateTransactionUseCase(txRepo),
      EditTransactionUseCase(txRepo),
    );
    addTearDown(cubit.close);

    await cubit.load(null);
    customersRepo.controller.add(
      Right([
        CustomerEntity(
          id: 'c1',
          name: 'Customer',
          phone: null,
          notes: null,
          balancePiasters: 0,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ]),
    );
    await Future<void>.delayed(Duration.zero);

    final pending = Completer<Either<AppFailure, TransactionEntity>>();
    txRepo.pendingCreate = pending;

    final firstSave = cubit.save(
      customerId: 'c1',
      type: TransactionType.credit,
      amount: '50',
      date: DateTime(2026, 1, 1),
    );
    final duplicateSave = cubit.save(
      customerId: 'c1',
      type: TransactionType.credit,
      amount: '50',
      date: DateTime(2026, 1, 1),
    );
    expect(cubit.state.saving, isTrue);
    expect(txRepo.createCalls, 1);

    pending.complete(const Left(AppFailure(AppErrorCode.database)));
    await Future.wait([firstSave, duplicateSave]);

    expect(cubit.state.saving, isFalse);
    expect(cubit.state.saved, isFalse);
    expect(
      cubit.state.submissionStatus,
      TransactionFormSubmissionStatus.failed,
    );
    expect(cubit.state.submissionId, 1);
    expect(
      cubit.state.submissionFailure,
      const AppFailure(AppErrorCode.database),
    );

    // A second identical failure still increments submissionId so listeners fire again.
    txRepo.pendingCreate = null;
    txRepo.createResult = const Left(AppFailure(AppErrorCode.database));
    await cubit.save(
      customerId: 'c1',
      type: TransactionType.credit,
      amount: '50',
      date: DateTime(2026, 1, 1),
    );
    expect(txRepo.createCalls, 2);
    expect(cubit.state.submissionId, 2);
    expect(
      cubit.state.submissionFailure,
      const AppFailure(AppErrorCode.database),
    );

    // Retrying and succeeding transitions to succeeded once.
    txRepo.createResult = null;
    await cubit.save(
      customerId: 'c1',
      type: TransactionType.payment,
      amount: '50',
      date: DateTime(2026, 1, 1),
    );
    expect(txRepo.createCalls, 3);
    expect(cubit.state.saved, isTrue);
    expect(cubit.state.savedType, TransactionType.payment);
    expect(cubit.state.submissionId, 3);
  });

  test('duplicate delete calls while pending run once and preserve deleteSubmissionId across stream updates', () async {
    final txRepo = _ControlledTransactionRepo();
    addTearDown(txRepo.dispose);
    final cubit = CustomerTransactionsCubit(
      WatchCustomerTransactionsUseCase(txRepo),
      SoftDeleteTransactionUseCase(txRepo),
    );
    addTearDown(cubit.close);

    await cubit.load('c1');
    final entry = TransactionEntity(
      id: 't1',
      customerId: 'c1',
      type: TransactionType.credit,
      amountPiasters: 5000,
      transactionDate: DateTime(2026, 1, 1),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    txRepo.entries.add(Right([entry]));
    await Future<void>.delayed(Duration.zero);

    final pending = Completer<Either<AppFailure, bool>>();
    txRepo.pendingDelete = pending;

    final firstDelete = cubit.delete('t1');
    final duplicateDelete = cubit.delete('t1');
    expect(cubit.state.deleting, isTrue);
    expect(cubit.state.deletingTransactionId, 't1');
    expect(txRepo.deleteCalls, 1);

    pending.complete(const Left(AppFailure(AppErrorCode.database)));
    await Future.wait([firstDelete, duplicateDelete]);
    expect(cubit.state.deleting, isFalse);
    expect(cubit.state.deletingTransactionId, isNull);
    expect(cubit.state.deleteStatus, TransactionDeleteStatus.failed);
    expect(cubit.state.deleteSubmissionId, 1);
    expect(cubit.state.deleteFailure, const AppFailure(AppErrorCode.database));

    txRepo.pendingDelete = null;
    txRepo.deleteResult = const Right(true);
    await cubit.delete('t1');
    expect(cubit.state.deleted, isTrue);
    expect(cubit.state.deleteSubmissionId, 2);

    // Subsequent live stream refresh preserves deleteSubmissionId.
    txRepo.entries.add(const Right([]));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.entries, isEmpty);
    expect(cubit.state.deleteSubmissionId, 2);
  });
}
