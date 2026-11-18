import 'money_utils.dart';

abstract final class AmountInputUtils {
  static String applyKeypadInput(String amount, String key) {
    if (key == 'back') {
      return amount.length > 1 ? amount.substring(0, amount.length - 1) : '0';
    }
    if (key == '.') {
      return amount.contains('.') ? amount : '$amount.';
    }
    final candidate = amount == '0' ? key : '$amount$key';
    final parts = candidate.split('.');
    if ((parts.length == 1 || parts.last.length <= 2) &&
        MoneyUtils.tryParseEgpToPiasters(candidate) != null) {
      return candidate;
    }
    return amount;
  }

  static String addEgp(String amount, int value) {
    final current = tryParseInputToPiasters(amount);
    if (current == null || current > MoneyUtils.maxPiasters - value * 100) {
      return amount;
    }
    return formatEditablePiasters(current + value * 100);
  }

  static String formatEditablePiasters(int piasters) {
    final whole = piasters ~/ 100;
    final fraction = piasters % 100;
    return fraction == 0
        ? '$whole'
        : '$whole.${fraction.toString().padLeft(2, '0')}';
  }

  static int? tryParseInputToPiasters(String amount) =>
      MoneyUtils.tryParseEgpToPiasters(
        amount.endsWith('.') ? amount.substring(0, amount.length - 1) : amount,
      );
}
