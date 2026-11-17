import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money_utils.dart';

class CustomerTransactionsSection extends StatelessWidget {
  const CustomerTransactionsSection({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    void open(String type) => context.pushNamed(
      AppRoutes.transactionNewName,
      queryParameters: {'customerId': customerId, 'type': type},
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: context.appColors.creditColor,
                ),
                onPressed: () => open('credit'),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(l10n.transactionCredit),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: context.appColors.paymentColor,
                ),
                onPressed: () => open('payment'),
                icon: const Icon(Icons.payments_outlined),
                label: Text(l10n.transactionPayment),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            Text(l10n.transactionHistory, style: context.textTheme.titleLarge),
            Chip(label: Text(l10n.transactionHistoryCount(3))),
          ],
        ),
        Text(l10n.transactionMockHistory, style: context.textTheme.bodySmall),
        SizedBox(height: AppSpacing.sm),
        for (final group in [
          (
            date: '24/10/2023',
            entries: [
              (
                id: 'sample-1',
                credit: true,
                amount: 45000,
                balance: 125000,
                time: '02:30',
              ),
              (
                id: 'sample-2',
                credit: false,
                amount: 20000,
                balance: 80000,
                time: '11:15',
              ),
            ],
          ),
          (
            date: '23/10/2023',
            entries: [
              (
                id: 'sample-3',
                credit: true,
                amount: 30000,
                balance: 100000,
                time: '06:45',
              ),
            ],
          ),
        ]) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(group.date, style: context.textTheme.titleSmall),
          ),
          for (final entry in group.entries)
            Card(
              child: Padding(
                padding: AppSpacing.customersCardPadding,
                child: Column(
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      children: [
                        Container(
                          padding: AppSpacing.badgePadding,
                          decoration: BoxDecoration(
                            color:
                                (entry.credit
                                        ? context.appColors.creditColor
                                        : context.appColors.paymentColor)
                                    .withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.pillRadius,
                            ),
                          ),
                          child: Text(
                            entry.credit
                                ? l10n.transactionCreditBadge
                                : l10n.transactionPaymentBadge,
                            style: TextStyle(
                              color: entry.credit
                                  ? context.appColors.creditColor
                                  : context.appColors.paymentColor,
                            ),
                          ),
                        ),
                        Text(
                          entry.credit
                              ? l10n.transactionSampleCredit
                              : l10n.transactionSamplePayment,
                        ),
                        Text(
                          '${entry.credit ? '-' : '+'}${MoneyUtils.formatPiasters(entry.amount, locale: locale)}',
                          style: TextStyle(
                            color: entry.credit
                                ? context.appColors.creditColor
                                : context.appColors.paymentColor,
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'edit') {
                              context.pushNamed(
                                AppRoutes.transactionEditName,
                                pathParameters: {'id': entry.id},
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.transactionMockNotice),
                                ),
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(l10n.transactionEditAction),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(l10n.transactionDeleteAction),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      children: [
                        Icon(Icons.access_time, size: AppSpacing.iconSmall),
                        Text(entry.time, textDirection: TextDirection.ltr),
                        Text(
                          entry.credit
                              ? l10n.transactionSampleCreditNote
                              : l10n.transactionSamplePaymentNote,
                        ),
                        Text(
                          '${l10n.transactionBalance}: ${MoneyUtils.formatPiasters(entry.balance, locale: locale)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
