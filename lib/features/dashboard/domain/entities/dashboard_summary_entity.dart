import 'package:equatable/equatable.dart';

import 'debtor_summary_entity.dart';
import 'recent_activity_entity.dart';

/// Snapshot of the dashboard aggregates and lists.
///
/// Totals are exact integer piasters: [totalOwedPiasters] sums only the positive
/// active balances, and [todayCollectionsPiasters] sums today's active payments.
class DashboardSummaryEntity extends Equatable {
  const DashboardSummaryEntity({
    required this.totalOwedPiasters,
    required this.debtorCount,
    required this.todayCollectionsPiasters,
    required this.topDebtors,
    required this.recentActivity,
  });

  const DashboardSummaryEntity.empty()
    : totalOwedPiasters = 0,
      debtorCount = 0,
      todayCollectionsPiasters = 0,
      topDebtors = const [],
      recentActivity = const [];

  final int totalOwedPiasters;

  /// Number of active customers with a positive balance, not the list length.
  final int debtorCount;
  final int todayCollectionsPiasters;
  final List<DebtorSummaryEntity> topDebtors;
  final List<RecentActivityEntity> recentActivity;

  bool get hasDebtors => topDebtors.isNotEmpty;

  bool get hasRecentActivity => recentActivity.isNotEmpty;

  @override
  List<Object?> get props => [
    totalOwedPiasters,
    debtorCount,
    todayCollectionsPiasters,
    topDebtors,
    recentActivity,
  ];
}
