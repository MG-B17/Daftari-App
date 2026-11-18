import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../errors/app_exception.dart';
import '../app_database.dart';
import 'dao_support.dart';

part 'transaction_dao.g.dart';

final class TransactionWithCustomer {
  const TransactionWithCustomer(this.transaction, this.customer);

  final TransactionRecord transaction;
  final Customer customer;
}

/// Transaction ledger operations, including atomic audited edits/deletes.
@DriftAccessor(tables: [Customers, Transactions, TransactionAuditLogs])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  static const _uuid = Uuid();

  /// Inserts a credit or payment entry for an active customer.
  ///
  /// A soft-deleted customer is rejected with [ValidationException]; a missing
  /// customer id is left to the foreign key constraint, which surfaces as
  /// [DatabaseException].
  Future<TransactionRecord> createTransaction({
    required String customerId,
    required String type,
    required int amountPiasters,
    DateTime? transactionDate,
    String? note,
  }) {
    return runDatabaseOperation(() async {
      _validate(type: type, amountPiasters: amountPiasters);
      await _requireActiveCustomer(customerId);
      final now = DateTime.now();
      final id = _uuid.v4();
      await into(transactions).insert(
        TransactionsCompanion(
          id: Value(id),
          customerId: Value(customerId),
          type: Value(type),
          amountPiasters: Value(amountPiasters),
          note: Value(trimmedOrNull(note)),
          transactionDate: Value(transactionDate ?? now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return (select(
        transactions,
      )..where((row) => row.id.equals(id))).getSingle();
    });
  }

  /// Reads a single transaction. Unless [includeDeleted] is set, both the
  /// transaction and its parent customer must be active.
  Future<TransactionRecord?> getTransactionById(
    String id, {
    bool includeDeleted = false,
  }) {
    return runDatabaseOperation(() {
      if (!includeDeleted) return _activeTransaction(id);
      return (select(
        transactions,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
    });
  }

  /// Active transactions belonging to an active customer, newest first.
  Future<List<TransactionRecord>> getCustomerTransactions(String customerId) =>
      runDatabaseOperation(() => _customerTransactionQuery(customerId).get());

  Stream<List<TransactionRecord>> watchCustomerTransactions(
    String customerId,
  ) => _customerTransactionQuery(customerId).watch();

  /// Recent active activity across active customers, newest first.
  Future<List<TransactionRecord>> getRecentTransactions({int limit = 20}) =>
      runDatabaseOperation(() => _recentTransactionQuery(limit).get());

  Stream<List<TransactionRecord>> watchRecentTransactions({int limit = 20}) =>
      _recentTransactionQuery(limit).watch();

  Stream<List<TransactionWithCustomer>> watchRecentTransactionsWithCustomer({
    int limit = 5,
  }) {
    final query = _activeTransactionRows()
      ..orderBy(_newestFirst)
      ..limit(limit);
    return query
        .map(
          (row) => TransactionWithCustomer(
            row.readTable(transactions),
            row.readTable(customers),
          ),
        )
        .watch();
  }

  Stream<int> watchTodayPaymentsPiasters(
    DateTime startOfDay,
    DateTime endOfDay,
  ) {
    final total = transactions.amountPiasters.sum();
    final query = selectOnly(transactions)
      ..addColumns([total])
      ..join([
        innerJoin(
          customers,
          customers.id.equalsExp(transactions.customerId),
          useColumns: false,
        ),
      ])
      ..where(
        transactions.deletedAt.isNull() &
            customers.deletedAt.isNull() &
            transactions.type.equals(TransactionTypes.payment) &
            transactions.transactionDate.isBiggerOrEqualValue(startOfDay) &
            transactions.transactionDate.isSmallerThanValue(endOfDay),
      );
    return query.map((row) => row.read(total) ?? 0).watchSingle();
  }

  Future<List<TransactionAuditLog>> getAuditLogs(String transactionId) {
    return runDatabaseOperation(
      () =>
          (select(transactionAuditLogs)
                ..where((row) => row.transactionId.equals(transactionId))
                ..orderBy([
                  (row) => OrderingTerm.asc(row.createdAt),
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get(),
    );
  }

  /// Atomically records the previous values in [transactionAuditLogs] and then
  /// updates the active transaction. Any failure rolls both changes back.
  Future<TransactionRecord> editTransaction({
    required String id,
    required String type,
    required int amountPiasters,
    required DateTime transactionDate,
    String? note,
  }) {
    return runDatabaseOperation(
      () => transaction(() async {
        _validate(type: type, amountPiasters: amountPiasters);
        final current = await _activeTransaction(id);
        if (current == null) throw const ValidationException();
        final now = DateTime.now();
        await _appendAuditLog(
          previous: current,
          action: TransactionAuditActions.edit,
          createdAt: now,
        );
        await (update(transactions)..where((row) => row.id.equals(id))).write(
          TransactionsCompanion(
            type: Value(type),
            amountPiasters: Value(amountPiasters),
            note: Value(trimmedOrNull(note)),
            transactionDate: Value(transactionDate),
            updatedAt: Value(now),
            localRevision: Value(current.localRevision + 1),
          ),
        );
        return (select(
          transactions,
        )..where((row) => row.id.equals(id))).getSingle();
      }),
    );
  }

  /// Atomically records the previous values in [transactionAuditLogs] and then
  /// soft-deletes the active transaction. Repeating the call is a no-op.
  Future<bool> softDeleteTransaction(String id) {
    return runDatabaseOperation(
      () => transaction(() async {
        final current = await _activeTransaction(id);
        if (current == null) return false;
        final now = DateTime.now();
        await _appendAuditLog(
          previous: current,
          action: TransactionAuditActions.delete,
          createdAt: now,
        );
        final updatedRows =
            await (update(
              transactions,
            )..where((row) => row.id.equals(id))).write(
              TransactionsCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
                localRevision: Value(current.localRevision + 1),
              ),
            );
        return updatedRows > 0;
      }),
    );
  }

  JoinedSelectStatement _activeTransactionRows() {
    return select(transactions).join([
      innerJoin(customers, customers.id.equalsExp(transactions.customerId)),
    ])..where(transactions.deletedAt.isNull() & customers.deletedAt.isNull());
  }

  Selectable<TransactionRecord> _customerTransactionQuery(String customerId) {
    final query = _activeTransactionRows()
      ..where(transactions.customerId.equals(customerId))
      ..orderBy(_newestFirst);
    return query.map((row) => row.readTable(transactions));
  }

  Selectable<TransactionRecord> _recentTransactionQuery(int limit) {
    final query = _activeTransactionRows()
      ..orderBy(_newestFirst)
      ..limit(limit);
    return query.map((row) => row.readTable(transactions));
  }

  Future<TransactionRecord?> _activeTransaction(String id) {
    final query = _activeTransactionRows()..where(transactions.id.equals(id));
    return query.map((row) => row.readTable(transactions)).getSingleOrNull();
  }

  Future<void> _appendAuditLog({
    required TransactionRecord previous,
    required String action,
    required DateTime createdAt,
  }) {
    return into(transactionAuditLogs).insert(
      TransactionAuditLogsCompanion(
        id: Value(_uuid.v4()),
        transactionId: Value(previous.id),
        action: Value(action),
        previousType: Value(previous.type),
        previousAmountPiasters: Value(previous.amountPiasters),
        previousNote: Value(previous.note),
        previousTransactionDate: Value(previous.transactionDate),
        createdAt: Value(createdAt),
      ),
    );
  }

  List<OrderingTerm> get _newestFirst => [
    OrderingTerm.desc(transactions.transactionDate),
    OrderingTerm.desc(transactions.createdAt),
    OrderingTerm.desc(transactions.id),
  ];

  static void _validate({required String type, required int amountPiasters}) {
    if (!TransactionTypes.values.contains(type)) {
      throw const ValidationException();
    }
    if (amountPiasters <= 0) throw const ValidationException();
  }

  /// Rejects a soft-deleted customer. A missing customer is deliberately left
  /// alone so the foreign key constraint reports it as a database failure.
  Future<void> _requireActiveCustomer(String customerId) async {
    final customer = await (select(
      customers,
    )..where((row) => row.id.equals(customerId))).getSingleOrNull();
    if (customer != null && customer.deletedAt != null) {
      throw const ValidationException();
    }
  }
}
