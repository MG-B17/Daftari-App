import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import 'recent_activity_row.dart';

class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({super.key, required this.activities});

  final List<RecentActivityPreview> activities;

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
            for (var index = 0; index < activities.length; index++) ...[
              if (index > 0)
                Padding(
                  padding: AppSpacing.dashboardDividerPadding,
                  child: Divider(
                    height: AppSpacing.hairline,
                    color: context.colorScheme.outline,
                  ),
                ),
              RecentActivityRow(activity: activities[index]),
            ],
          ],
        ),
      ),
    ],
  );
}
