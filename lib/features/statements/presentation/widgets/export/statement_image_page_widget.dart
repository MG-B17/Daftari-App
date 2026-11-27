import 'package:flutter/material.dart';

import '../../../../../core/theme/colors/app_colors.dart';
import '../../../../../core/theme/spacing/app_spacing.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/customer_statement_entity.dart';
import '../../../domain/entities/statement_image_page.dart';
import 'statement_image_header.dart';
import 'statement_image_summary.dart';
import 'statement_image_entries_list.dart';
import 'statement_image_footer.dart';

class StatementImagePageWidget extends StatelessWidget {
  const StatementImagePageWidget({
    super.key,
    required this.statement,
    required this.page,
    required this.labels,
  });

  final CustomerStatementEntity statement;
  final StatementImagePage page;
  final AppLocalizations labels;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.noScaling),
    child: Directionality(
      textDirection: labels.localeName.startsWith('ar')
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: AppSpacing.exportFont,
          height: 1.6,
          color: AppColors.text,
        ),
        child: IconTheme(
          data: const IconThemeData(color: AppColors.primary),
          child: Container(
            width: AppSpacing.exportWidth,
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppSpacing.exportPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatementImageHeader(
                  statement: statement,
                  page: page,
                  labels: labels,
                ),
                if (page.isFirst)
                  StatementImageSummary(statement: statement, labels: labels),
                const SizedBox(height: AppSpacing.exportGap),
                StatementImageEntriesList(page: page, labels: labels),
                const SizedBox(height: AppSpacing.exportGap),
                StatementImageFooter(
                  statement: statement,
                  page: page,
                  labels: labels,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
