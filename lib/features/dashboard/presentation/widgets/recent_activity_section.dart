import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../domain/entities/recent_activity_entity.dart';
import 'recent_activity_row.dart';

class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({
    super.key,
    required this.activities,
    required this.onOpenCustomer,
    required this.updatedLive,
  });

  final List<RecentActivityEntity> activities;
  final ValueChanged<String> onOpenCustomer;
  final bool updatedLive;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: AppSpacing.dashboardSectionHeaderPadding,
        child: Row(
          children: [
            Container(
              width: AppSpacing.dashboardSectionBarWidth,
              height: AppSpacing.dashboardSectionBarHeight,
              decoration: BoxDecoration(
                color: context.colorScheme.primary,
                borderRadius: BorderRadius.circular(
                  AppSpacing.dashboardSectionBarWidth,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.l10n.dashboardRecentActivity,
                style: context.textTheme.titleLarge,
              ),
            ),
            if (updatedLive)
              Text(
                context.l10n.dashboardUpdatedLive,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (activities.isEmpty)
              Padding(
                key: const ValueKey('dashboard-no-activity'),
                padding: AppSpacing.dashboardCardPadding,
                child: Text(context.l10n.transactionHistoryEmpty),
              ),
            for (var index = 0; index < activities.length; index++) ...[
              if (index > 0)
                Padding(
                  padding: AppSpacing.dashboardDividerPadding,
                  child: Divider(
                    height: AppSpacing.hairline,
                    color: context.colorScheme.outline,
                  ),
                ),
              RecentActivityRow(
                key: ValueKey('dashboard-activity-${activities[index].id}'),
                activity: activities[index],
                onTap: () => onOpenCustomer(activities[index].customerId),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
