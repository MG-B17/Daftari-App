import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/statements/domain/entities/customer_statement_entity.dart';
import 'package:daftariapp/features/statements/domain/entities/statement_date_range.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';

final statementNow = DateTime(2026, 11, 20, 15, 30);

CustomerEntity statementCustomer({String? phone = '01012345678'}) =>
    CustomerEntity(
      id: 'c1',
      name: 'Test Customer',
      phone: phone,
      notes: 'Private customer notes',
      balancePiasters: 999999,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

TransactionEntity statementTransaction({
  String id = 't1',
  String customerId = 'c1',
  TransactionType type = TransactionType.credit,
  int amount = 101,
  DateTime? date,
  DateTime? createdAt,
  String? note,
}) => TransactionEntity(
  id: id,
  customerId: customerId,
  type: type,
  amountPiasters: amount,
  transactionDate: date ?? statementNow,
  createdAt: createdAt ?? statementNow,
  updatedAt: statementNow,
  note: note,
);

CustomerStatementEntity statementFixture({
  List<TransactionEntity> entries = const [],
  StatementDateRange range = StatementDateRange.all,
  String? phone = '01012345678',
}) => CustomerStatementEntity.fromLedger(
  customer: statementCustomer(phone: phone),
  activeTransactions: entries,
  generatedAt: statementNow,
  range: range,
);
