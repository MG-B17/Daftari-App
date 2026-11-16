import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/utils/money_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tryParseEgpToPiasters', () {
    final cases = <String, int>{
      '0': 0,
      '0.01': 1,
      '0.1': 10,
      '1.10': 110,
      '1250': 125000,
      '1250.50': 125050,
      ' 12.34 ': 1234,
      '١٢٥٠٫٥٠': 125050,
      '١٢.٣٤': 1234,
      '12٫٣': 1230,
      '٠٫٠١': 1,
      '0001.02': 102,
      '90071992547409.91': MoneyUtils.maxPiasters,
    };
    for (final entry in cases.entries) {
      test('parses ${entry.key} exactly', () {
        expect(MoneyUtils.tryParseEgpToPiasters(entry.key), entry.value);
      });
    }
    for (final input in [
      '',
      ' ',
      '-1',
      '+1',
      '1.234',
      '١٫٢٣٤',
      '.5',
      '1.',
      '1,000',
      '١٬٠٠٠',
      '1 2',
      '1.2.3',
      '1٫2.3',
      'NaN',
      'Infinity',
      '1e3',
      'EGP 1',
      '1\n2',
      '90071992547409.92',
      '99999999999999999999999999999999999999',
    ]) {
      test('rejects malformed or out-of-range input: $input', () {
        expect(MoneyUtils.tryParseEgpToPiasters(input), isNull);
      });
    }
    test('adding decimal amounts never drifts', () {
      expect(
        MoneyUtils.tryParseEgpToPiasters('0.1')! +
            MoneyUtils.tryParseEgpToPiasters('0.2')!,
        30,
      );
    });
  });

  group('formatPiasters', () {
    test('approved Arabic examples and English currency', () {
      expect(MoneyUtils.formatPiasters(125000), '1,250 ج.م');
      expect(MoneyUtils.formatPiasters(125050), '1,250.50 ج.م');
      expect(MoneyUtils.formatPiasters(125001, locale: 'en'), '1,250.01 EGP');
      expect(MoneyUtils.formatPiasters(0), '0 ج.م');
      expect(MoneyUtils.formatPiasters(1), '0.01 ج.م');
      expect(MoneyUtils.formatPiasters(-1), '-0.01 ج.م');
      expect(
        MoneyUtils.formatPiasters(-125050, includeCurrency: false),
        '-1,250.50',
      );
    });
    test('exact at the cross-platform limit, not rounded via double', () {
      expect(
        MoneyUtils.formatPiasters(MoneyUtils.maxPiasters),
        '90,071,992,547,409.91 ج.م',
      );
      expect(
        MoneyUtils.formatPiasters(-MoneyUtils.maxPiasters, locale: 'en'),
        '-90,071,992,547,409.91 EGP',
      );
      expect(
        () => MoneyUtils.formatPiasters(MoneyUtils.maxPiasters + 1),
        throwsA(isA<ValidationException>()),
      );
    });
    test('formatted positive amounts round trip exactly', () {
      for (final value in [
        0,
        1,
        10,
        99,
        100,
        101,
        125050,
        MoneyUtils.maxPiasters,
      ]) {
        final text = MoneyUtils.formatPiasters(
          value,
          includeCurrency: false,
        ).replaceAll(',', '');
        expect(MoneyUtils.tryParseEgpToPiasters(text), value);
      }
    });
  });
}
