import 'package:daftariapp/core/utils/amount_input_utils.dart';
import 'package:daftariapp/core/utils/money_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyKeypadInput', () {
    test('handles digits, decimal precision and backspace', () {
      var amount = '0';
      for (final key in ['1', '2', '.', '3', '4', '5', '.']) {
        amount = AmountInputUtils.applyKeypadInput(amount, key);
      }
      expect(amount, '12.34');
      expect(AmountInputUtils.applyKeypadInput(amount, 'back'), '12.3');
      expect(AmountInputUtils.applyKeypadInput('0.', 'back'), '0');
      expect(AmountInputUtils.applyKeypadInput('0', 'back'), '0');
      expect(AmountInputUtils.applyKeypadInput('0', '0'), '0');
      expect(AmountInputUtils.applyKeypadInput('0', 'x'), '0');
    });

    test('rejects a digit that exceeds the supported limit', () {
      expect(
        AmountInputUtils.applyKeypadInput('90071992547409.9', '2'),
        '90071992547409.9',
      );
      expect(
        AmountInputUtils.applyKeypadInput('90071992547409.9', '1'),
        '90071992547409.91',
      );
    });
  });

  group('addEgp', () {
    test('adds shortcuts exactly including fractional amounts', () {
      var amount = '0.';
      for (final value in [50, 100, 200, 500]) {
        amount = AmountInputUtils.addEgp(amount, value);
      }
      expect(amount, '850');
      expect(AmountInputUtils.addEgp('0.01', 50), '50.01');
      expect(AmountInputUtils.addEgp('12.3', 100), '112.30');
    });

    test('leaves invalid and overflowing inputs unchanged', () {
      expect(AmountInputUtils.addEgp('invalid', 50), 'invalid');
      expect(
        AmountInputUtils.addEgp('90071992547359.91', 50),
        '90071992547409.91',
      );
      expect(
        AmountInputUtils.addEgp('90071992547359.92', 50),
        '90071992547359.92',
      );
    });
  });

  test('formats editable piasters without grouping or currency', () {
    expect(AmountInputUtils.formatEditablePiasters(0), '0');
    expect(AmountInputUtils.formatEditablePiasters(1), '0.01');
    expect(AmountInputUtils.formatEditablePiasters(1230), '12.30');
    expect(AmountInputUtils.formatEditablePiasters(12300), '123');
    expect(
      AmountInputUtils.formatEditablePiasters(MoneyUtils.maxPiasters),
      '90071992547409.91',
    );
  });

  test('parses editable input and permits a trailing decimal point', () {
    expect(AmountInputUtils.tryParseInputToPiasters('12.'), 1200);
    expect(AmountInputUtils.tryParseInputToPiasters('١٢٫٣'), 1230);
    expect(AmountInputUtils.tryParseInputToPiasters('.'), isNull);
    expect(AmountInputUtils.tryParseInputToPiasters('1.234'), isNull);
    expect(
      AmountInputUtils.tryParseInputToPiasters('90071992547409.92'),
      isNull,
    );
  });
}
