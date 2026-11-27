import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';

class DashboardTotalAmount extends StatelessWidget {
  const DashboardTotalAmount({
    super.key,
    required this.piasters,
    required this.color,
  });

  final int piasters;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final money = context.formatMoney(piasters);
    final parts = money.split(' ');
    final amount = parts.first;
    final currency = parts.skip(1).join(' ');
    return Semantics(
      label: money,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            amount,
            style: context.textTheme.headlineMedium?.copyWith(color: color),
          ),
          if (currency.isNotEmpty) ...[
            SizedBox(width: AppSpacing.xs),
            Text(
              currency,
              style: context.textTheme.titleMedium?.copyWith(color: color),
            ),
          ],
        ],
      ),
    );
  }
}
