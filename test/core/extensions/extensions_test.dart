import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/extensions/string_extensions.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('digit normalization preserves other text and is idempotent', () {
    expect('٠١٢٣٤٥٦٧٨٩'.toWesternDigits, '0123456789');
    final text = 'علي 01٢٣٫٤٥ +20 😀';
    expect(text.toWesternDigits, 'علي 0123٫45 +20 😀');
    expect(text.toWesternDigits.toWesternDigits, text.toWesternDigits);
    expect(''.toWesternDigits, '');
    expect(' \n '.nullIfBlank, isNull);
    expect(' علي '.nullIfBlank, 'علي');
  });

  for (final locale in [const Locale('ar'), const Locale('en')]) {
    testWidgets('context extensions resolve ${locale.languageCode}', (
      tester,
    ) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        captured.l10n.appTitle,
        locale.languageCode == 'ar' ? 'دفتري' : 'Daftari',
      );
      expect(captured.theme, same(Theme.of(captured)));
      expect(captured.colorScheme, same(Theme.of(captured).colorScheme));
      expect(captured.textTheme, same(Theme.of(captured).textTheme));
    });
  }
}
