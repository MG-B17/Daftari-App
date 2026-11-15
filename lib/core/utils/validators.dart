import '../extensions/string_extensions.dart';
import 'money_utils.dart';

/// Returns safe validation messages, never echoing the user's input.
abstract final class Validators {
  static String? customerName(String? value, {String locale = 'ar'}) =>
      value == null || value.trim().isEmpty
      ? _message(locale, 'أدخل اسم العميل', 'Enter a customer name')
      : null;

  static String? egyptianMobile(String? value, {String locale = 'ar'}) {
    final phone = value?.trim().toWesternDigits;
    if (phone == null || phone.isEmpty) return null;
    return RegExp(r'^(?:01[0125]\d{8}|\+201[0125]\d{8})$').hasMatch(phone)
        ? null
        : _message(
            locale,
            'أدخل رقم موبايل مصري صحيح',
            'Enter a valid Egyptian mobile number',
          );
  }

  static String? positivePiasters(int? value, {String locale = 'ar'}) =>
      value != null && value > 0 && value <= MoneyUtils.maxPiasters
      ? null
      : _message(
          locale,
          'أدخل مبلغًا أكبر من صفر',
          'Enter an amount greater than zero',
        );

  static String? email(String? value, {String locale = 'ar'}) {
    final email = value?.trim() ?? '';
    final valid =
        RegExp(
          r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)+$",
        ).hasMatch(email) &&
        !email.startsWith('.') &&
        !email.contains('..') &&
        !email.contains('.@');
    return valid
        ? null
        : _message(
            locale,
            'أدخل بريدًا إلكترونيًا صحيحًا',
            'Enter a valid email address',
          );
  }

  /// Minimum eight characters; passwords are not trimmed or normalized.
  static String? password(String? value, {String locale = 'ar'}) =>
      value != null && value.runes.length >= 8 && value.trim().isNotEmpty
      ? null
      : _message(
          locale,
          'كلمة المرور يجب ألا تقل عن ٨ أحرف',
          'Use at least 8 characters',
        );

  static String? pin(String? value, {String locale = 'ar'}) =>
      value != null && RegExp(r'^[0-9]{4}$').hasMatch(value.toWesternDigits)
      ? null
      : _message(locale, 'أدخل رمزًا من ٤ أرقام', 'Enter a 4-digit PIN');

  static String _message(String locale, String ar, String en) =>
      locale.startsWith('ar') ? ar : en;
}
