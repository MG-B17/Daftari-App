import 'package:equatable/equatable.dart';

enum TransactionType { credit, payment }

class TransactionEntity extends Equatable {
  const TransactionEntity({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amountPiasters,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final String id;
  final String customerId;
  final TransactionType type;
  final int amountPiasters;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? note;

  @override
  List<Object?> get props => [
    id,
    customerId,
    type,
    amountPiasters,
    transactionDate,
    createdAt,
    updatedAt,
    note,
  ];
}
