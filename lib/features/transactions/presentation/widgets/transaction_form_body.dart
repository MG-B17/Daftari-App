import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../../core/widgets/app_button.dart';

class TransactionFormBody extends StatefulWidget {
  const TransactionFormBody({
    super.key,
    this.customerId,
    this.initialType,
    this.isEdit = false,
  });

  final String? customerId;
  final String? initialType;
  final bool isEdit;

  @override
  State<TransactionFormBody> createState() => _TransactionFormBodyState();
}

class _TransactionFormBodyState extends State<TransactionFormBody> {
  late bool payment = widget.initialType == 'payment';
  String amount = '0';
  DateTime date = DateTime.now();

  void input(String key) {
    setState(() {
      if (key == 'back') {
        amount = amount.length > 1
            ? amount.substring(0, amount.length - 1)
            : '0';
      } else if (key == '.') {
        if (!amount.contains('.')) amount += '.';
      } else {
        final candidate = amount == '0' ? key : '$amount$key';
        final parts = candidate.split('.');
        if ((parts.length == 1 || parts.last.length <= 2) &&
            MoneyUtils.tryParseEgpToPiasters(candidate) != null) {
          amount = candidate;
        }
      }
    });
  }

  void add(int value) {
    final current = MoneyUtils.tryParseEgpToPiasters(
      amount.endsWith('.') ? amount.substring(0, amount.length - 1) : amount,
    );
    if (current == null || current > MoneyUtils.maxPiasters - value * 100) {
      return;
    }
    final result = current + value * 100;
    setState(() {
      amount = '${result ~/ 100}';
      if (result % 100 != 0) {
        amount += '.${(result % 100).toString().padLeft(2, '0')}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = payment
        ? context.appColors.paymentColor
        : context.appColors.creditColor;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: AppSpacing.customersMaxWidth),
        child: ListView(
          children: [
            Text(l10n.transactionMockNotice, textAlign: TextAlign.center),
            SizedBox(height: AppSpacing.sm),
            Container(
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
                            ? l10n.transactionPayment
                            : l10n.transactionCredit,
                        icon: option
                            ? Icons.payments_outlined
                            : Icons.trending_up,
                        variant: payment == option
                            ? (option
                                  ? AppButtonVariant.payment
                                  : AppButtonVariant.credit)
                            : AppButtonVariant.outlined,
                        onPressed: () => setState(() => payment = option),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(
                  widget.customerId == null
                      ? l10n.transactionChooseCustomer
                      : l10n.transactionCustomer,
                ),
                trailing: TextButton(
                  onPressed: null,
                  child: Text(l10n.transactionChange),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Card(
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
                      '$amount ${Localizations.localeOf(context).languageCode == 'ar' ? 'ج.م' : 'EGP'}',
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
                            onPressed: () => add(value),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(l10n.transactionDate),
                subtitle: Text(
                  AppDateUtils.formatDate(
                    date,
                    locale: Localizations.localeOf(context).languageCode,
                  ),
                ),
                trailing: Text(l10n.transactionChange),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (selected != null && mounted) {
                    setState(() => date = selected);
                  }
                },
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.edit_note),
                hintText: l10n.transactionNote,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Container(
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
                                  onPressed: () => input(key),
                                  child: key == 'back'
                                      ? Icon(
                                          Icons.backspace_outlined,
                                          semanticLabel:
                                              l10n.transactionBackspace,
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
            ),
            SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.transactionMockNotice)),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(l10n.transactionSave),
            ),
          ],
        ),
      ),
    );
  }
}
