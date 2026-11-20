import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class StatementEntryTile extends StatelessWidget {
  const StatementEntryTile({
    super.key,
    required this.note,
    required this.amount,
    required this.date,
  });

  final String note;
  final int amount;
  final String date;

  @override
  Widget build(BuildContext context) {
    final credit = amount > 0;
    final color = credit
        ? context.appColors.creditColor
        : context.appColors.paymentColor;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: AppSpacing.compact,
            backgroundColor: credit
                ? context.appColors.creditSurface
                : context.appColors.paymentSurface,
            child: Icon(
              credit ? Icons.add : Icons.remove,
              size: AppSpacing.iconSmall,
              color: color,
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note),
                Text(date, style: context.textTheme.bodySmall),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  context.formatMoney(amount.abs()),
                  style: context.textTheme.bodyMedium?.copyWith(color: color),
                ),
                Text(
                  credit
                      ? context.l10n.transactionCreditBadge
                      : context.l10n.transactionPaymentBadge,
                  style: context.textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
