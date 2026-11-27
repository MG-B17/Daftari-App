import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';

class DashboardTodayCollections extends StatelessWidget {
  const DashboardTodayCollections({super.key, required this.piasters});

  final int piasters;

  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.badgePadding,
    decoration: BoxDecoration(
      color: context.appColors.customersAccentSurface,
      borderRadius: BorderRadius.circular(AppSpacing.dashboardChipRadius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.dashboardTodayCollections,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: AppSpacing.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            '+${context.formatMoney(piasters)}',
            maxLines: 1,
            style: context.textTheme.titleMedium?.copyWith(
              color: context.appColors.paymentColor,
            ),
          ),
        ),
      ],
    ),
  );
}
