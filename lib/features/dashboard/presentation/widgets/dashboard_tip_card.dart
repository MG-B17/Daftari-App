import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class DashboardTipCard extends StatelessWidget {
  const DashboardTipCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.dashboardCardPadding,
    decoration: BoxDecoration(
      color: context.appColors.customersAccentSurface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Text(
                context.l10n.dashboardTipTitle,
                textAlign: TextAlign.center,
                style: context.textTheme.titleMedium,
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                context.l10n.dashboardTipMessage,
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.compact),
        Container(
          width: AppSpacing.dashboardTipIconBox,
          height: AppSpacing.dashboardTipIconBox,
          decoration: BoxDecoration(
            color: context.colorScheme.primary.withValues(alpha: .18),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.verified_rounded,
            size: AppSpacing.icon,
            color: context.colorScheme.primary,
          ),
        ),
      ],
    ),
  );
}
