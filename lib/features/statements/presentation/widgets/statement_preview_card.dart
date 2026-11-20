import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/customer_statement_entity.dart';
import '../../domain/entities/statement_date_range.dart';
import '../cubit/statement_cubit.dart';

class StatementPreviewCard extends StatelessWidget {
  const StatementPreviewCard({super.key, required this.statement});

  final CustomerStatementEntity statement;

  Future<void> _customRange(BuildContext context) async {
    final cubit = context.read<StatementCubit>();
    final range = statement.range;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      currentDate: statement.generatedAt,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: DatePickerTheme.of(context).copyWith(
            rangePickerHeaderHeadlineStyle: context.textTheme.titleMedium,
          ),
        ),
        child: child!,
      ),
      initialDateRange: range.type == StatementDateRangeType.custom
          ? DateTimeRange(start: range.start!, end: range.end!)
          : null,
    );
    if (!context.mounted || picked == null) return;
    await cubit.setRange(
      StatementDateRange.custom(start: picked.start, end: picked.end),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final generatedAt = statement.generatedAt;
    final balance = statement.balancePiasters;
    final creditBalance = balance > 0;
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
                              Text(statement.customer.name),
                              if (statement.customer.phone?.trim().isNotEmpty ??
                                  false)
                                Text(
                                  statement.customer.phone!.trim(),
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
              color: creditBalance
                  ? context.appColors.creditSurface
                  : context.appColors.paymentSurface,
              child: Column(
                children: [
                  Text(l10n.statementBalance, textAlign: TextAlign.center),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    context.formatMoney(balance),
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
                        : balance < 0
                        ? l10n.statementCreditBalanceHint
                        : l10n.statementSettledHint,
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
                          key: ValueKey('statement-range-$index'),
                          selected: statement.range.type.index == index,
                          onSelected: (_) {
                            if (index == 3) {
                              _customRange(context);
                            } else {
                              context.read<StatementCubit>().setRange(
                                [
                                  StatementDateRange.all,
                                  StatementDateRange.last30Days,
                                  StatementDateRange.thisMonth,
                                ][index],
                              );
                            }
                          },
                        ),
                    ],
                  ),
                  if (statement.range.type == StatementDateRangeType.custom)
                    Text(
                      '${AppDateUtils.formatDate(statement.range.start!, locale: locale)}'
                      ' – ${AppDateUtils.formatDate(statement.range.end!, locale: locale)}',
                    ),
                  SizedBox(height: AppSpacing.sm),
                  const Divider(),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.statementEntriesTitle,
                    style: context.textTheme.titleMedium,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  if (statement.entries.isEmpty) Text(l10n.statementEmpty),
                  for (final entry in statement.entries)
                    _StatementEntry(
                      key: ValueKey('statement-entry-${entry.id}'),
                      note: entry.note?.trim().isNotEmpty ?? false
                          ? entry.note!.trim()
                          : entry.type == TransactionType.credit
                          ? l10n.transactionCreditBadge
                          : l10n.transactionPaymentBadge,
                      amount: entry.type == TransactionType.credit
                          ? entry.amountPiasters
                          : -entry.amountPiasters,
                      date: AppDateUtils.formatDate(
                        entry.transactionDate,
                        locale: locale,
                      ),
                    ),
                  const Divider(),
                  Text(
                    l10n.statementPeriodCredit(
                      context.formatMoney(statement.periodCreditPiasters),
                    ),
                  ),
                  Text(
                    l10n.statementPeriodPayment(
                      context.formatMoney(statement.periodPaymentPiasters),
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
