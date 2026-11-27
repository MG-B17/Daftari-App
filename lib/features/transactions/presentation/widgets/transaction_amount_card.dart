import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/utils/money_utils.dart';

class TransactionAmountCard extends StatelessWidget {
  const TransactionAmountCard({
    super.key,
    required this.amount,
    required this.payment,
    required this.onAdd,
    this.enabled = true,
  });

  final String amount;
  final bool payment;
  final ValueChanged<int> onAdd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = payment
        ? context.appColors.paymentColor
        : context.appColors.creditColor;
    return Card(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.transactionAmount),
                Flexible(
                  child: Text(
                    l10n.transactionQuickAmounts,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              '$amount ${MoneyUtils.currencyLabel(Localizations.localeOf(context).languageCode)}',
              textDirection: TextDirection.ltr,
              style: context.textTheme.headlineMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final value in [50, 100, 200, 500])
                  ActionChip(
                    label: Text('+$value'),
                    onPressed: enabled ? () => onAdd(value) : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
