import 'package:equatable/equatable.dart';

enum CustomerFilter { all, owes, settled }

enum CustomerSort { nameAsc, balanceDesc, recent }

class CustomerEntity extends Equatable {
  const CustomerEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.notes,
    required this.balancePiasters,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final int balancePiasters;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    notes,
    balancePiasters,
    createdAt,
    updatedAt,
  ];
}
