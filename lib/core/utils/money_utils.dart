import '../errors/app_exception.dart';
import '../extensions/string_extensions.dart';

abstract final class MoneyUtils {
  /// Cross-platform exact integer limit, including Dart compiled to JavaScript.
  static const maxPiasters = 9007199254740991;
  static final _max = BigInt.from(maxPiasters);
  static final _input = RegExp(r'^[0-9]+(?:[.٫][0-9]{1,2})?$');

  static String currencyLabel(String locale) =>
      locale.startsWith('ar') ? 'ج.م' : 'EGP';

  static int? tryParseEgpToPiasters(String input) {
    final value = input.trim().toWesternDigits;
    if (!_input.hasMatch(value)) return null;
    final parts = value.split(RegExp('[.٫]'));
    final whole = BigInt.parse(parts.first);
    final fraction = parts.length == 1
        ? 0
        : int.parse(parts[1].padRight(2, '0'));
    final piasters = whole * BigInt.from(100) + BigInt.from(fraction);
    return piasters > _max ? null : piasters.toInt();
  }

  /// Western digits and comma grouping match the approved Arabic money design.
  /// Never converts to double, even for very large values or negative balances.
  static String formatPiasters(
    int piasters, {
    String locale = 'ar',
    bool includeCurrency = true,
  }) {
    if (piasters < -maxPiasters || piasters > maxPiasters) {
      throw const ValidationException();
    }
    final amount = piasters.abs();
    final whole = (amount ~/ 100).toString();
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final fraction = amount % 100;
    final decimals = fraction == 0
        ? ''
        : '.${fraction.toString().padLeft(2, '0')}';
    final sign = piasters < 0 ? '-' : '';
    final currency = currencyLabel(locale);
    return '$sign$grouped$decimals${includeCurrency ? ' $currency' : ''}';
  }
}
