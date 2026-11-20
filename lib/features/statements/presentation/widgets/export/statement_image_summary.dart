import 'package:flutter/widgets.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/money_utils.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/customer_statement_entity.dart';

class StatementImageSummary extends StatelessWidget {
  const StatementImageSummary({
    super.key,
    required this.statement,
    required this.labels,
  });
  final CustomerStatementEntity statement;
  final AppLocalizations labels;

  @override
  Widget build(BuildContext context) {
    String money(int value) =>
        MoneyUtils.formatPiasters(value, locale: labels.localeName);
    final owes = statement.balancePiasters > 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.exportGap),
      decoration: BoxDecoration(
        color: owes ? AppColors.creditSurface : AppColors.paymentSurface,
        borderRadius: BorderRadius.circular(AppSpacing.exportRadius),
      ),
      child: Column(
        children: [
          Text(labels.statementBalance),
          Text(
            money(statement.balancePiasters),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppSpacing.exportAmountFont,
              fontWeight: FontWeight.bold,
              color: owes ? AppColors.credit : AppColors.payment,
            ),
          ),
          if (statement.balancePiasters <= 0)
            Text(
              statement.balancePiasters < 0
                  ? labels.statementCreditBalanceHint
                  : labels.statementSettledHint,
            ),
          Text(
            labels.statementPeriodCredit(money(statement.periodCreditPiasters)),
          ),
          Text(
            labels.statementPeriodPayment(
              money(statement.periodPaymentPiasters),
            ),
          ),
        ],
      ),
    );
  }
}
