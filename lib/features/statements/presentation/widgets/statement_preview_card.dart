import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/customer_statement_entity.dart';
import 'statement_balance_banner.dart';
import 'statement_entry_tile.dart';
import 'statement_header_section.dart';
import 'statement_range_filter.dart';

class StatementPreviewCard extends StatelessWidget {
  const StatementPreviewCard({super.key, required this.statement});

  final CustomerStatementEntity statement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    return ClipRRect(
      borderRadius: AppSpacing.borderRadius,
      child: ColoredBox(
        color: context.appColors.cardPaperSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatementHeaderSection(statement: statement),
            StatementBalanceBanner(balancePiasters: statement.balancePiasters),
            Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StatementRangeFilter(
                    range: statement.range,
                    generatedAt: statement.generatedAt,
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
                    StatementEntryTile(
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
