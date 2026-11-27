import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;

import '../../../../../core/theme/colors/app_colors.dart';
import '../../../../../core/theme/spacing/app_spacing.dart';
import '../../../../../core/utils/app_date_utils.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/customer_statement_entity.dart';
import '../../../domain/entities/statement_date_range.dart';
import '../../../domain/entities/statement_image_page.dart';

class StatementImageHeader extends StatelessWidget {
  const StatementImageHeader({
    super.key,
    required this.statement,
    required this.page,
    required this.labels,
  });
  final CustomerStatementEntity statement;
  final StatementImagePage page;
  final AppLocalizations labels;

  @override
  Widget build(BuildContext context) {
    String date(DateTime value) =>
        AppDateUtils.formatDate(value, locale: labels.localeName);
    final range = switch (statement.range.type) {
      StatementDateRangeType.all => labels.statementRangeAll,
      StatementDateRangeType.last30Days => labels.statementRangeLast30Days,
      StatementDateRangeType.thisMonth => labels.statementRangeThisMonth,
      StatementDateRangeType.custom =>
        '${date(statement.range.start!)} – ${date(statement.range.end!)}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.receipt_long_outlined),
            const SizedBox(width: AppSpacing.exportSmallGap),
            Expanded(
              child: Text(
                labels.appTitle,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: AppSpacing.exportTitleFont,
                ),
              ),
            ),
            if (page.total > 1)
              Text(
                labels.statementImagePage(page.number, page.total),
                textDirection: TextDirection.ltr,
              ),
          ],
        ),
        Text(
          labels.statementImageTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(statement.customer.name),
        if (page.isFirst &&
            (statement.customer.phone?.trim().isNotEmpty ?? false))
          Text(
            statement.customer.phone!.trim(),
            textDirection: TextDirection.ltr,
          ),
        Text(range),
        if (page.isFirst)
          Text(
            labels.statementGeneratedAt(
              date(statement.generatedAt),
              AppDateUtils.formatTime(
                statement.generatedAt,
                locale: labels.localeName,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.exportGap),
      ],
    );
  }
}
