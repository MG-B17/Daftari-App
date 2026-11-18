import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

class TransactionTypeToggle extends StatelessWidget {
  const TransactionTypeToggle({
    super.key,
    required this.payment,
    required this.onChanged,
  });
  final bool payment;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(AppSpacing.xs),
    decoration: BoxDecoration(
      color: context.appColors.customersAccentSurface,
      borderRadius: AppSpacing.borderRadius,
    ),
    child: Row(
      children: [
        for (final option in [false, true])
          Expanded(
            child: AppButton(
              label: option
                  ? context.l10n.transactionPayment
                  : context.l10n.transactionCredit,
              icon: option ? Icons.payments_outlined : Icons.trending_up,
              variant: payment == option
                  ? (option
                        ? AppButtonVariant.payment
                        : AppButtonVariant.credit)
                  : AppButtonVariant.outlined,
              onPressed: () => onChanged(option),
            ),
          ),
      ],
    ),
  );
}
