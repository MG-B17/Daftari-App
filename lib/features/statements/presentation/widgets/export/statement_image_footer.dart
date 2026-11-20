import 'package:flutter/widgets.dart';

import '../../../../../core/utils/app_date_utils.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/customer_statement_entity.dart';
import '../../../domain/entities/statement_image_page.dart';

class StatementImageFooter extends StatelessWidget {
  const StatementImageFooter({
    super.key,
    required this.statement,
    required this.page,
    required this.labels,
  });
  final CustomerStatementEntity statement;
  final StatementImagePage page;
  final AppLocalizations labels;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(labels.statementImageFooter, textAlign: TextAlign.center),
      Text(
        labels.statementGeneratedAt(
          AppDateUtils.formatDate(
            statement.generatedAt,
            locale: labels.localeName,
          ),
          AppDateUtils.formatTime(
            statement.generatedAt,
            locale: labels.localeName,
          ),
        ),
        textAlign: TextAlign.center,
      ),
      if (page.total > 1)
        Text(
          labels.statementImagePage(page.number, page.total),
          textDirection: TextDirection.ltr,
        ),
    ],
  );
}
