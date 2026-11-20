import 'package:flutter/widgets.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/app_date_utils.dart';
import '../../../../../core/utils/money_utils.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../../transactions/domain/entities/transaction_entity.dart';
import '../../../domain/entities/statement_image_page.dart';

class StatementImageEntriesList extends StatelessWidget {
  const StatementImageEntriesList({
    super.key,
    required this.page,
    required this.labels,
  });
  final StatementImagePage page;
  final AppLocalizations labels;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        labels.statementEntriesTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      if (page.entries.isEmpty)
        Padding(
          padding: const EdgeInsets.all(AppSpacing.exportGap),
          child: Text(labels.statementEmpty),
        ),
      for (final entry in page.entries)
        Container(
          key: ValueKey('statement-image-entry-${entry.id}'),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.exportGap),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppDateUtils.formatDate(
                        entry.transactionDate,
                        locale: labels.localeName,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.exportSmallGap,
                    ),
                    color: entry.type == TransactionType.credit
                        ? AppColors.creditSurface
                        : AppColors.paymentSurface,
                    child: Text(
                      entry.type == TransactionType.credit
                          ? labels.transactionCreditBadge
                          : labels.transactionPaymentBadge,
                    ),
                  ),
                ],
              ),
              Text(
                MoneyUtils.formatPiasters(
                  entry.amountPiasters,
                  locale: labels.localeName,
                ),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: entry.type == TransactionType.credit
                      ? AppColors.credit
                      : AppColors.payment,
                ),
              ),
              if (entry.note?.trim().isNotEmpty ?? false)
                Text(entry.note!.trim()),
            ],
          ),
        ),
    ],
  );
}
