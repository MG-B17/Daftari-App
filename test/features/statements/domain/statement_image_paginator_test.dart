import 'package:daftariapp/features/statements/domain/entities/statement_image_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statement_fixtures.dart';

void main() {
  test('empty history still has one page', () {
    final page = StatementImagePaginator.paginate([]).single;
    expect(page.entries, isEmpty);
    expect(page.number, 1);
    expect(page.total, 1);
  });

  for (final count in [1, 4, 14, 1000]) {
    test('$count transactions appear exactly once in original order', () {
      final entries = List.generate(
        count,
        (i) => statementTransaction(id: '$i'),
      );
      final pages = StatementImagePaginator.paginate(entries);
      expect(pages.expand((p) => p.entries), orderedEquals(entries));
      expect(
        pages.map((p) => p.number),
        List.generate(pages.length, (i) => i + 1),
      );
      expect(pages.map((p) => p.total), everyElement(pages.length));
      expect(pages.every((p) => p.entries.isNotEmpty), isTrue);
      expect(() => pages.first.entries.clear(), throwsUnsupportedError);
    });
  }

  test(
    'long notes and explicit newlines reduce page capacity without omission',
    () {
      final entries = List.generate(
        30,
        (i) =>
            statementTransaction(id: '$i', note: '${'Long note ' * 30}\n\n\n'),
      );
      final pages = StatementImagePaginator.paginate(entries);
      expect(pages.length, greaterThan(5));
      expect(pages.expand((p) => p.entries), orderedEquals(entries));
    },
  );
}
