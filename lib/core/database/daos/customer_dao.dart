import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../errors/app_exception.dart';
import '../app_database.dart';
import 'dao_support.dart';

part 'customer_dao.g.dart';

final class CustomerWithBalance {
  const CustomerWithBalance(this.customer, this.balancePiasters);
  final Customer customer;
  final int balancePiasters;
}

/// Aggregated ledger figures for the dashboard.
///
/// Every amount is an exact integer number of piasters; balances are always
/// derived from active transactions of active customers.
final class DashboardTotals extends Equatable {
  const DashboardTotals({
    required this.activeCustomers,
    required this.totalCreditPiasters,
    required this.totalPaymentPiasters,
  });

  const DashboardTotals.empty()
    : activeCustomers = 0,
      totalCreditPiasters = 0,
      totalPaymentPiasters = 0;

  final int activeCustomers;
  final int totalCreditPiasters;
  final int totalPaymentPiasters;

  int get balancePiasters => totalCreditPiasters - totalPaymentPiasters;

  @override
  List<Object?> get props => [
    activeCustomers,
    totalCreditPiasters,
    totalPaymentPiasters,
  ];
}

/// Customer CRUD, search, derived balances, and dashboard aggregates.
@DriftAccessor(tables: [Customers, Transactions])
class CustomerDao extends DatabaseAccessor<AppDatabase>
    with _$CustomerDaoMixin {
  CustomerDao(super.db);

  static const _uuid = Uuid();

  Future<Customer> createCustomer({
    required String name,
    String? phone,
    String? notes,
  }) {
    return runDatabaseOperation(() async {
      final trimmedName = _validateName(name);
      final now = DateTime.now();
      final id = _uuid.v4();
      await into(customers).insert(
        CustomersCompanion(
          id: Value(id),
          name: Value(trimmedName),
          phone: Value(trimmedOrNull(phone)),
          notes: Value(trimmedOrNull(notes)),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return (select(customers)..where((row) => row.id.equals(id))).getSingle();
    });
  }

  Future<Customer?> getCustomerById(String id, {bool includeDeleted = false}) {
    return runDatabaseOperation(() {
      final query = select(customers)..where((row) => row.id.equals(id));
      if (!includeDeleted) {
        query.where((row) => row.deletedAt.isNull());
      }
      return query.getSingleOrNull();
    });
  }

  Future<List<Customer>> getActiveCustomers() =>
      runDatabaseOperation(_activeCustomers().get);

  Stream<List<Customer>> watchActiveCustomers() => _activeCustomers().watch();

  Stream<List<CustomerWithBalance>> watchCustomersWithBalances({String? id}) {
    final credit = transactions.amountPiasters.sum(
      filter: transactions.type.equals(TransactionTypes.credit),
    );
    final payment = transactions.amountPiasters.sum(
      filter: transactions.type.equals(TransactionTypes.payment),
    );
    final query =
        select(customers).join([
            leftOuterJoin(
              transactions,
              transactions.customerId.equalsExp(customers.id) &
                  transactions.deletedAt.isNull(),
              useColumns: false,
            ),
          ])
          ..addColumns([credit, payment])
          ..where(customers.deletedAt.isNull())
          ..groupBy([customers.id]);
    if (id != null) query.where(customers.id.equals(id));
    return query.watch().map(
      (rows) => rows
          .map(
            (row) => CustomerWithBalance(
              row.readTable(customers),
              (row.read(credit) ?? 0) - (row.read(payment) ?? 0),
            ),
          )
          .toList(),
    );
  }

  Future<List<Customer>> searchCustomers(String query) {
    final term = query.trim();
    if (term.isEmpty) return getActiveCustomers();
    return runDatabaseOperation(_activeSearch(term).get);
  }

  Stream<List<Customer>> watchSearchCustomers(String query) {
    final term = query.trim();
    if (term.isEmpty) return watchActiveCustomers();
    return _activeSearch(term).watch();
  }

  /// Updates an active customer's profile and bumps [Customers.localRevision].
  /// Returns `false` when the customer does not exist or is soft-deleted.
  Future<bool> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? notes,
  }) {
    return runDatabaseOperation(
      () => transaction(() async {
        final current = await _activeCustomer(id);
        if (current == null) return false;
        final now = DateTime.now();
        final updatedRows =
            await (update(customers)..where((row) => row.id.equals(id))).write(
              CustomersCompanion(
                name: Value(_validateName(name)),
                phone: Value(trimmedOrNull(phone)),
                notes: Value(trimmedOrNull(notes)),
                updatedAt: Value(now),
                localRevision: Value(current.localRevision + 1),
              ),
            );
        return updatedRows > 0;
      }),
    );
  }

  /// Soft-deletes an active customer and bumps [Customers.localRevision].
  /// Returns `false` when the customer is already deleted or missing.
  Future<bool> softDeleteCustomer(String id) {
    return runDatabaseOperation(
      () => transaction(() async {
        final current = await _activeCustomer(id);
        if (current == null) return false;
        final now = DateTime.now();
        final updatedRows =
            await (update(customers)..where((row) => row.id.equals(id))).write(
              CustomersCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
                localRevision: Value(current.localRevision + 1),
              ),
            );
        return updatedRows > 0;
      }),
    );
  }

  /// `sum(active credit) - sum(active payment)` for an active customer.
  /// Returns `0` when the customer is missing or soft-deleted.
  Future<int> getCustomerBalance(String customerId) =>
      runDatabaseOperation(() => _balanceQuery(customerId).getSingle());

  Stream<int> watchCustomerBalance(String customerId) =>
      _balanceQuery(customerId).watchSingle();

  Future<DashboardTotals> getDashboardTotals() =>
      runDatabaseOperation(() => _dashboardQuery().getSingle());

  Stream<DashboardTotals> watchDashboardTotals() =>
      _dashboardQuery().watchSingle();

  SimpleSelectStatement<$CustomersTable, Customer> _activeCustomers() {
    return select(customers)
      ..where((row) => row.deletedAt.isNull())
      ..orderBy([
        (row) => OrderingTerm.asc(row.name),
        (row) => OrderingTerm.asc(row.id),
      ]);
  }

  SimpleSelectStatement<$CustomersTable, Customer> _activeSearch(String term) {
    return select(customers)
      ..where(
        (row) =>
            row.deletedAt.isNull() &
            (row.name.contains(term) | row.phone.contains(term)),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.name),
        (row) => OrderingTerm.asc(row.id),
      ]);
  }

  Future<Customer?> _activeCustomer(String id) {
    return (select(customers)
          ..where((row) => row.id.equals(id) & row.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Selectable<int> _balanceQuery(String customerId) {
    final credit = transactions.amountPiasters.sum(
      filter:
          transactions.type.equals(TransactionTypes.credit) &
          transactions.deletedAt.isNull(),
    );
    final payment = transactions.amountPiasters.sum(
      filter:
          transactions.type.equals(TransactionTypes.payment) &
          transactions.deletedAt.isNull(),
    );
    final query = transactions.selectOnly()
      ..addColumns([credit, payment])
      ..join([
        innerJoin(customers, customers.id.equalsExp(transactions.customerId)),
      ])
      ..where(
        transactions.customerId.equals(customerId) &
            transactions.deletedAt.isNull() &
            customers.deletedAt.isNull(),
      );
    return query.map(
      (row) => (row.read(credit) ?? 0) - (row.read(payment) ?? 0),
    );
  }

  Selectable<DashboardTotals> _dashboardQuery() {
    final credit = transactions.amountPiasters.sum(
      filter:
          transactions.type.equals(TransactionTypes.credit) &
          transactions.deletedAt.isNull(),
    );
    final payment = transactions.amountPiasters.sum(
      filter:
          transactions.type.equals(TransactionTypes.payment) &
          transactions.deletedAt.isNull(),
    );
    final customerCount = customers.id.count(distinct: true);
    final query = customers.selectOnly()
      ..addColumns([customerCount, credit, payment])
      ..join([
        leftOuterJoin(
          transactions,
          transactions.customerId.equalsExp(customers.id) &
              transactions.deletedAt.isNull(),
        ),
      ])
      ..where(customers.deletedAt.isNull());
    return query.map(
      (row) => DashboardTotals(
        activeCustomers: row.read(customerCount) ?? 0,
        totalCreditPiasters: row.read(credit) ?? 0,
        totalPaymentPiasters: row.read(payment) ?? 0,
      ),
    );
  }

  static String _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const ValidationException();
    return trimmed;
  }
}
