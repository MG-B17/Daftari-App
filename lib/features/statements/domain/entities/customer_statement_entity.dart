import 'package:equatable/equatable.dart';

import '../../../customers/domain/entities/customer_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import 'statement_date_range.dart';

class CustomerStatementEntity extends Equatable {
  CustomerStatementEntity._({
    required this.customer,
    required List<TransactionEntity> entries,
    required this.range,
    required this.balancePiasters,
    required this.periodCreditPiasters,
    required this.periodPaymentPiasters,
    required this.generatedAt,
  }) : entries = List.unmodifiable(entries);

  // The repository supplies an active customer and their complete active ledger.
  factory CustomerStatementEntity.fromLedger({
    required CustomerEntity customer,
    required Iterable<TransactionEntity> activeTransactions,
    required DateTime generatedAt,
    StatementDateRange range = StatementDateRange.all,
  }) {
    var balance = 0;
    var credit = 0;
    var payment = 0;
    final entries = <TransactionEntity>[];
    for (final transaction in activeTransactions) {
      if (transaction.customerId != customer.id) {
        throw ArgumentError('Statement ledger customer mismatch.');
      }
      final isCredit = transaction.type == TransactionType.credit;
      balance += isCredit
          ? transaction.amountPiasters
          : -transaction.amountPiasters;
      if (!range.contains(transaction.transactionDate, now: generatedAt)) {
        continue;
      }
      entries.add(transaction);
      if (isCredit) {
        credit += transaction.amountPiasters;
      } else {
        payment += transaction.amountPiasters;
      }
    }
    entries.sort((a, b) {
      final date = b.transactionDate.compareTo(a.transactionDate);
      if (date != 0) return date;
      final created = b.createdAt.compareTo(a.createdAt);
      return created != 0 ? created : a.id.compareTo(b.id);
    });
    return CustomerStatementEntity._(
      customer: customer,
      entries: entries,
      range: range,
      balancePiasters: balance,
      periodCreditPiasters: credit,
      periodPaymentPiasters: payment,
      generatedAt: generatedAt,
    );
  }

  final CustomerEntity customer;
  final List<TransactionEntity> entries;
  final StatementDateRange range;
  final int balancePiasters;
  final int periodCreditPiasters;
  final int periodPaymentPiasters;
  final DateTime generatedAt;

  @override
  List<Object?> get props => [
    customer,
    entries,
    range,
    balancePiasters,
    periodCreditPiasters,
    periodPaymentPiasters,
    generatedAt,
  ];
}
