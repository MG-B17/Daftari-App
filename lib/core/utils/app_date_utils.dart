import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

abstract final class AppDateUtils {
  /// Called during DI bootstrap, before localized date formatting is needed.
  static Future<void> initialize() => initializeDateFormatting();

  static String formatDate(DateTime date, {String locale = 'ar'}) =>
      DateFormat.yMMMd(locale).format(date.toLocal());

  static String formatTime(DateTime date, {String locale = 'ar'}) =>
      DateFormat.jm(locale).format(date.toLocal());

  static bool isToday(DateTime date, {DateTime? now}) =>
      _sameDay(date.toLocal(), (now ?? DateTime.now()).toLocal());

  static bool isYesterday(DateTime date, {DateTime? now}) {
    final localNow = (now ?? DateTime.now()).toLocal();
    // Calendar arithmetic rather than a 24-hour duration (DST safe).
    final yesterday = DateTime(localNow.year, localNow.month, localNow.day - 1);
    return _sameDay(date.toLocal(), yesterday);
  }

  static String relativeDay(
    DateTime date, {
    String locale = 'ar',
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final arabic = locale.startsWith('ar');
    if (isToday(date, now: reference)) return arabic ? 'اليوم' : 'Today';
    if (isYesterday(date, now: reference)) return arabic ? 'أمس' : 'Yesterday';
    return formatDate(date, locale: locale);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
