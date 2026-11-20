import 'dart:ui' as ui;

import 'package:daftariapp/core/services/widget_image_exporter.dart';
import 'package:daftariapp/core/theme/app_colors.dart';
import 'package:daftariapp/core/theme/app_spacing.dart';
import 'package:daftariapp/core/utils/app_date_utils.dart';
import 'package:daftariapp/features/customers/domain/entities/customer_entity.dart';
import 'package:daftariapp/features/statements/domain/entities/customer_statement_entity.dart';
import 'package:daftariapp/features/statements/domain/entities/statement_image_page.dart';
import 'package:daftariapp/features/statements/presentation/services/statement_image_renderer.dart';
import 'package:daftariapp/features/statements/presentation/widgets/export/statement_image_page_widget.dart';
import 'package:daftariapp/features/statements/presentation/widgets/export/statement_image_summary.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/statement_fixtures.dart';

void main() {
  setUpAll(AppDateUtils.initialize);

  for (final locale in ['ar', 'en']) {
    testWidgets(
      '$locale export wraps long content with fixed light colors and page numbers',
      (tester) async {
        final customer = CustomerEntity(
          id: 'c1',
          name: 'اسم العميل الطويل Long customer name ' * 5,
          phone: '01012345678',
          notes: null,
          balancePiasters: 0,
          createdAt: statementNow,
          updatedAt: statementNow,
        );
        final statement = CustomerStatementEntity.fromLedger(
          customer: customer,
          generatedAt: statementNow,
          activeTransactions: List.generate(
            20,
            (i) => statementTransaction(
              id: '$i',
              amount: 999999999999,
              note: 'ملاحظة طويلة Long note\n' * 12,
            ),
          ),
        );
        final labels = await AppLocalizations.delegate.load(Locale(locale));
        final pages = StatementImagePaginator.paginate(statement.entries);
        expect(pages.length, greaterThan(1));
        for (final page in [pages.first, pages.last]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              home: SingleChildScrollView(
                child: Center(
                  child: StatementImagePageWidget(
                    statement: statement,
                    page: page,
                    labels: labels,
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          final imageContext = tester.element(
            find.text(labels.statementImageTitle),
          );
          expect(
            Directionality.of(imageContext),
            locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(
            find.text(labels.statementImagePage(page.number, pages.length)),
            findsNWidgets(2),
          );
          expect(
            tester
                .widgetList<Text>(
                  find.text(
                    labels.statementImagePage(page.number, pages.length),
                  ),
                )
                .map((text) => text.textDirection),
            everyElement(TextDirection.ltr),
          );
          expect(
            find.byType(StatementImageSummary),
            page.isFirst ? findsOneWidget : findsNothing,
          );
          for (final entry in page.entries) {
            expect(
              find.byKey(ValueKey('statement-image-entry-${entry.id}')),
              findsOneWidget,
            );
            expect(find.text(entry.note!.trim()), findsWidgets);
          }
          final container = tester
              .widgetList<Container>(find.byType(Container))
              .firstWhere((c) => c.color == AppColors.surface);
          expect(container.constraints!.maxWidth, AppSpacing.exportWidth);
        }
      },
    );

    testWidgets('$locale empty image includes localized empty state', (
      tester,
    ) async {
      final labels = await AppLocalizations.delegate.load(Locale(locale));
      await tester.pumpWidget(
        StatementImagePageWidget(
          statement: statementFixture(),
          page: StatementImagePaginator.paginate([]).single,
          labels: labels,
        ),
      );
      expect(find.text(labels.statementEmpty), findsOneWidget);
      expect(find.text(labels.statementImageFooter), findsOneWidget);
      expect(find.text(labels.statementImagePage(1, 1)), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$locale single-page image trims phone and notes and omits blank notes',
      (tester) async {
        const phone = ' 01012345678 ';
        const note = ' \n مشتريات groceries \n ';
        const blankNote = ' \n\t ';
        final statement = statementFixture(
          phone: phone,
          entries: [
            statementTransaction(id: 'noted', note: note),
            statementTransaction(id: 'blank', note: blankNote),
          ],
        );
        final labels = await AppLocalizations.delegate.load(Locale(locale));
        await tester.pumpWidget(
          MaterialApp(
            home: SingleChildScrollView(
              child: StatementImagePageWidget(
                statement: statement,
                page: StatementImagePaginator.paginate(statement.entries)
                    .single,
                labels: labels,
              ),
            ),
          ),
        );
        expect(find.text(labels.statementImagePage(1, 1)), findsNothing);
        expect(find.text(phone.trim()), findsOneWidget);
        expect(find.text(phone), findsNothing);
        expect(find.text(note.trim()), findsOneWidget);
        expect(find.text(note), findsNothing);
        expect(find.text(blankNote), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('statement-image-entry-blank')),
            matching: find.byType(Text),
          ),
          findsNWidgets(3),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('real renderer produces sequential decodable bounded PNGs', (
    tester,
  ) async {
    final statement = statementFixture(
      entries: List.generate(
        16,
        (i) => statementTransaction(id: '$i', note: 'مشتريات groceries ' * 8),
      ),
    );
    final renderer = WidgetStatementImageRenderer(WidgetImageExporter());
    var count = 0;
    await tester.runAsync(() async {
      await for (final bytes in renderer.render(statement, locale: 'ar')) {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 1050);
        expect(frame.image.height, lessThanOrEqualTo(8192));
        frame.image.dispose();
        codec.dispose();
        count++;
      }
    });
    expect(count, StatementImagePaginator.paginate(statement.entries).length);
    expect(tester.takeException(), isNull);
  });
}
