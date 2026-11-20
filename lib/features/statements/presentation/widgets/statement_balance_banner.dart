import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class StatementBalanceBanner extends StatelessWidget {
  const StatementBalanceBanner({super.key, required this.balancePiasters});

  final int balancePiasters;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final creditBalance = balancePiasters > 0;
    return Container(
      padding: AppSpacing.pagePadding,
      color: creditBalance
          ? context.appColors.creditSurface
          : context.appColors.paymentSurface,
      child: Column(
        children: [
          Text(l10n.statementBalance, textAlign: TextAlign.center),
          SizedBox(height: AppSpacing.sm),
          Text(
            context.formatMoney(balancePiasters),
            key: const ValueKey('statement-balance'),
            style: context.textTheme.headlineMedium?.copyWith(
              color: creditBalance
                  ? context.appColors.creditColor
                  : context.appColors.paymentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            creditBalance
                ? l10n.statementBalanceHint
                : balancePiasters < 0
                ? l10n.statementCreditBalanceHint
                : l10n.statementSettledHint,
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
