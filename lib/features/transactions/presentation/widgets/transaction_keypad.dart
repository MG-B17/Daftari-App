import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class TransactionKeypad extends StatelessWidget {
  const TransactionKeypad({super.key, required this.onInput});
  final ValueChanged<String> onInput;

  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.customersCardPadding,
    decoration: BoxDecoration(
      color: context.appColors.customersAccentSurface,
      borderRadius: AppSpacing.borderRadius,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['.', '0', 'back'],
          ])
            Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xxs),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: key == 'back'
                              ? context.colorScheme.primaryContainer
                              : context.colorScheme.surface,
                          foregroundColor: key == 'back'
                              ? context.appColors.creditColor
                              : context.colorScheme.onSurface,
                        ),
                        onPressed: () => onInput(key),
                        child: key == 'back'
                            ? Icon(
                                Icons.backspace_outlined,
                                semanticLabel:
                                    context.l10n.transactionBackspace,
                              )
                            : Text(key),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}
