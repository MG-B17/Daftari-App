import 'package:equatable/equatable.dart';

/// A customer with an outstanding balance, ranked for the dashboard list.
///
/// [balancePiasters] is always a positive integer amount of piasters: only
/// active customers whose active credit exceeds their active payments qualify.
class DebtorSummaryEntity extends Equatable {
  const DebtorSummaryEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.balancePiasters,
  });

  final String id;
  final String name;
  final String? phone;
  final int balancePiasters;

  @override
  List<Object?> get props => [id, name, phone, balancePiasters];
}
