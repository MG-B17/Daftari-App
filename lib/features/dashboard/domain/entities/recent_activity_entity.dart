import 'package:equatable/equatable.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';

/// A recent ledger entry shown on the dashboard, enriched with its customer.
class RecentActivityEntity extends Equatable {
  const RecentActivityEntity({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.type,
    required this.amountPiasters,
    required this.transactionDate,
    this.note,
  });

  final String id;
  final String customerId;
  final String customerName;
  final TransactionType type;
  final int amountPiasters;
  final DateTime transactionDate;
  final String? note;

  bool get isCredit => type == TransactionType.credit;

  @override
  List<Object?> get props => [
    id,
    customerId,
    customerName,
    type,
    amountPiasters,
    transactionDate,
    note,
  ];
}
