import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

typedef TopDebtorPreview = ({String name, String? phone, int balancePiasters});

class TopDebtorRow extends StatelessWidget {
  const TopDebtorRow({super.key, required this.debtor, required this.top});

  final TopDebtorPreview debtor;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final creditColor = context.appColors.creditColor;
    return Padding(
      padding: AppSpacing.dashboardCardPadding,
      child: Row(
        children: [
          CircleAvatar(
            radius: AppSpacing.dashboardAvatarRadius,
            backgroundColor: top
                ? creditColor.withValues(alpha: .12)
                : context.appColors.customersAccentSurface,
            child: Text(
              _initial(debtor.name),
              style: TextStyle(
                color: top ? creditColor : context.colorScheme.primary,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(debtor.name, style: context.textTheme.titleSmall),
                if (debtor.phone != null)
                  Text(debtor.phone!, textDirection: TextDirection.ltr),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                context.formatMoney(debtor.balancePiasters),
                style: context.textTheme.titleMedium?.copyWith(
                  color: creditColor,
                ),
              ),
              SizedBox(height: AppSpacing.xs),
              Container(
                padding: AppSpacing.badgePadding,
                decoration: BoxDecoration(
                  color: creditColor.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                ),
                child: Text(
                  context.l10n.transactionCreditBadge,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: creditColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// First grapheme of a name, or `?` when the name is blank.
String _initial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first;
}
