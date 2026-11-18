import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/debtor_summary_entity.dart';
import 'top_debtor_row.dart';

class TopDebtorsSection extends StatelessWidget {
  const TopDebtorsSection({
    super.key,
    required this.debtors,
    required this.onViewAll,
    required this.onOpenCustomer,
  });

  final List<DebtorSummaryEntity> debtors;
  final VoidCallback onViewAll;
  final ValueChanged<String> onOpenCustomer;

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
                color: context.appColors.creditColor,
                borderRadius: BorderRadius.circular(
                  AppSpacing.dashboardSectionBarWidth,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.l10n.dashboardTopDebtors,
                style: context.textTheme.titleLarge,
              ),
            ),
            TextButton(
              key: const ValueKey('dashboard-view-all-debtors'),
              onPressed: onViewAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.dashboardViewAll),
                  Icon(
                    Icons.chevron_right,
                    size: AppSpacing.iconSmall,
                    color: context.colorScheme.primary,
                  ),
                ],
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
            if (debtors.isEmpty)
              Padding(
                key: const ValueKey('dashboard-no-debtors'),
                padding: AppSpacing.dashboardCardPadding,
                child: Text(context.l10n.emptyTitle),
              ),
            for (var index = 0; index < debtors.length; index++) ...[
              if (index > 0)
                Padding(
                  padding: AppSpacing.dashboardDividerPadding,
                  child: Divider(
                    height: AppSpacing.hairline,
                    color: context.colorScheme.outline,
                  ),
                ),
              TopDebtorRow(
                key: ValueKey('dashboard-debtor-${debtors[index].id}'),
                debtor: debtors[index],
                top: index == 0,
                onTap: () => onOpenCustomer(debtors[index].id),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
