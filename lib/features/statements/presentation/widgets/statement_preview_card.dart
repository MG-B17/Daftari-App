import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_date_utils.dart';

class StatementPreviewCard extends StatelessWidget {
  const StatementPreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final generatedAt = DateTime(2023, 10, 24, 15);
    final entries = [
      (note: l10n.statementSampleCredit1, amount: 45000, day: 24),
      (note: l10n.statementSamplePayment1, amount: -20000, day: 24),
      (note: l10n.statementSampleCredit2, amount: 30000, day: 23),
      (note: l10n.statementSamplePayment2, amount: -50000, day: 12),
      (note: l10n.statementSampleCredit3, amount: 120000, day: 10),
    ];
    final balance = entries.fold(0, (total, entry) => total + entry.amount);
    return ClipRRect(
      borderRadius: AppSpacing.borderRadius,
      child: ColoredBox(
        color: context.appColors.cardPaperSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: AppSpacing.statementBrandBar,
              color: context.appColors.brand,
            ),
            Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        color: context.colorScheme.primary,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.appTitle,
                          style: context.textTheme.titleLarge,
                        ),
                      ),
                      Icon(
                        Icons.receipt_long_outlined,
                        color: context.colorScheme.primary,
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.statementGeneratedAt(
                      AppDateUtils.formatDate(generatedAt, locale: locale),
                      AppDateUtils.formatTime(generatedAt, locale: locale),
                    ),
                    style: context.textTheme.bodySmall,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Container(
                    padding: AppSpacing.controlPadding,
                    decoration: BoxDecoration(
                      color: context.appColors.customersAccentSurface,
                      borderRadius: AppSpacing.borderRadius,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.statementSampleCustomer),
                              const Text(
                                '01098765432',
                                textDirection: TextDirection.ltr,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: AppSpacing.pagePadding,
              color: context.appColors.creditSurface,
              child: Column(
                children: [
                  Text(l10n.statementBalance, textAlign: TextAlign.center),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    context.formatMoney(balance),
                    key: const ValueKey('statement-balance'),
                    style: context.textTheme.headlineMedium?.copyWith(
                      color: context.appColors.creditColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.statementBalanceHint,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final (index, label) in [
                        l10n.statementRangeAll,
                        l10n.statementRangeLast30Days,
                        l10n.statementRangeThisMonth,
                        l10n.statementRangeCustom,
                      ].indexed)
                        ChoiceChip(
                          label: Text(label),
                          selected: index == 0,
                          onSelected: null,
                        ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  const Divider(),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.statementEntriesTitle,
                    style: context.textTheme.titleMedium,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  for (final entry in entries)
                    _StatementEntry(
                      note: entry.note,
                      amount: entry.amount,
                      date: AppDateUtils.formatDate(
                        DateTime(2023, 10, entry.day),
                        locale: locale,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: AppSpacing.pagePadding,
              color: context.appColors.customersAccentSurface,
              child: Text(
                l10n.statementFooter,
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatementEntry extends StatelessWidget {
  const _StatementEntry({
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
