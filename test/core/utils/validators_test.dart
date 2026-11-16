import 'package:daftariapp/core/utils/money_utils.dart';
import 'package:daftariapp/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer name is required and trimmed', () {
    for (final value in [null, '', ' \n ']) {
      expect(Validators.customerName(value), isNotNull);
    }
    expect(Validators.customerName(' علي '), isNull);
  });

  test('Egyptian phone is optional and accepts all four valid prefixes', () {
    for (final value in [
      null,
      '',
      ' ',
      '01012345678',
      '01112345678',
      '01212345678',
      '01512345678',
      '+201012345678',
      ' ٠١٠١٢٣٤٥٦٧٨ ',
      '+٢٠١٥١٢٣٤٥٦٧٨',
    ]) {
      expect(Validators.egyptianMobile(value), isNull, reason: '$value');
    }
    for (final value in [
      '01312345678',
      '0101234567',
      '010123456789',
      '201012345678',
      '+441012345678',
      '010 12345678',
      'abcdefghijk',
    ]) {
      expect(Validators.egyptianMobile(value), isNotNull, reason: value);
    }
  });

  test('amount requires positive supported integer piasters', () {
    for (final value in [null, 0, -1, MoneyUtils.maxPiasters + 1]) {
      expect(Validators.positivePiasters(value), isNotNull);
    }
    expect(Validators.positivePiasters(1), isNull);
    expect(Validators.positivePiasters(MoneyUtils.maxPiasters), isNull);
  });

  test('email validation', () {
    for (final value in ['a@example.com', ' user+tag@example.co.uk ']) {
      expect(Validators.email(value), isNull);
    }
    for (final value in [
      null,
      '',
      'a',
      'a@',
      '@example.com',
      'a@x',
      'a b@example.com',
      'a..b@example.com',
      'a.@example.com',
      'a@-example.com',
      'a@example-.com',
      'a@ex!ample.com',
      'a(b)@example.com',
    ]) {
      expect(Validators.email(value), isNotNull);
    }
  });

  test('password minimum length and PIN exact numeric length', () {
    expect(Validators.password('pass1234'), isNull);
    for (final value in [null, '', '1234567', '        ']) {
      expect(Validators.password(value), isNotNull);
    }
    for (final value in ['1234', '٠١٢٣', '0000']) {
      expect(Validators.pin(value), isNull);
    }
    for (final value in [null, '', '123', '12345', '12a4', ' 1234', '12.4']) {
      expect(Validators.pin(value), isNotNull);
    }
  });

  test('localized errors never echo input', () {
    expect(
      Validators.egyptianMobile('sensitive phone', locale: 'en'),
      'Enter a valid Egyptian mobile number',
    );
    expect(Validators.customerName('', locale: 'ar'), 'أدخل اسم العميل');
    expect(
      Validators.email('private invalid address'),
      isNot(contains('private')),
    );
  });
}
