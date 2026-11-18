import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import 'dashboard_today_collections.dart';
import 'dashboard_total_amount.dart';

class DashboardSummaryCard extends StatelessWidget {
  const DashboardSummaryCard({
    super.key,
    required this.totalOwedPiasters,
    required this.debtorCount,
    required this.todayCollectionsPiasters,
    required this.onRegisterTransaction,
    required this.onNewCustomer,
  });

  final int totalOwedPiasters;
  final int debtorCount;
  final int todayCollectionsPiasters;
  final VoidCallback onRegisterTransaction;
  final VoidCallback onNewCustomer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final creditColor = context.appColors.creditColor;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppSpacing.dashboardCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: AppSpacing.iconSmall,
                            color: creditColor,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              l10n.dashboardTotalOwed,
                              style: context.textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: DashboardTotalAmount(
                          piasters: totalOwedPiasters,
                          color: creditColor,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: AppSpacing.tight,
                            color: creditColor,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              l10n.dashboardDebtorCount(debtorCount),
                              style: context.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.compact),
                Expanded(
                  child: DashboardTodayCollections(
                    piasters: todayCollectionsPiasters,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppSpacing.dashboardActionHeight,
                    child: FilledButton.icon(
                      key: const ValueKey('dashboard-register-transaction'),
                      onPressed: onRegisterTransaction,
                      icon: const Icon(Icons.edit_note),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.dashboardRegisterTransaction),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SizedBox(
                    height: AppSpacing.dashboardActionHeight,
                    child: FilledButton.icon(
                      key: const ValueKey('dashboard-new-customer'),
                      onPressed: onNewCustomer,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            context.appColors.customersAccentSurface,
                        foregroundColor: context.colorScheme.primary,
                      ),
                      icon: const Icon(Icons.person_add_alt),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.dashboardNewCustomer),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
