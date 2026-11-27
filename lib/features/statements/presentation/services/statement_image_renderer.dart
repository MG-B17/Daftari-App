import 'dart:typed_data';

import '../../../../core/services/image_exporter/widget_image_exporter.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../l10n/generated/app_localizations.dart';

import 'package:flutter/widgets.dart';

import '../../domain/entities/customer_statement_entity.dart';
import '../../domain/entities/statement_image_page.dart';
import '../widgets/export/statement_image_page_widget.dart';

abstract class StatementImageRenderer {
  Stream<Uint8List> render(
    CustomerStatementEntity statement, {
    required String locale,
  });
}

class WidgetStatementImageRenderer implements StatementImageRenderer {
  WidgetStatementImageRenderer(this._exporter);
  final WidgetImageExporter _exporter;

  @override
  Stream<Uint8List> render(
    CustomerStatementEntity statement, {
    required String locale,
  }) async* {
    final labels = await AppLocalizations.delegate.load(
      Locale(locale.startsWith('ar') ? 'ar' : 'en'),
    );
    for (final page in StatementImagePaginator.paginate(statement.entries)) {
      yield await _exporter.export(
        StatementImagePageWidget(
          statement: statement,
          page: page,
          labels: labels,
        ),
        width: AppSpacing.exportWidth,
      );
    }
  }
}
