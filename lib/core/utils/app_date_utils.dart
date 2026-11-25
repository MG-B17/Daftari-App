import 'package:intl/date_symbol_data_custom.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart';

abstract final class AppDateUtils {
  static bool _initialized = false;

  static final DateSymbols _enSymbols = DateSymbols.deserializeFromMap({
    ...en_USSymbols.serializeToMap(),
    'NAME': 'en',
  });

  static final DateSymbols _arSymbols = DateSymbols(
    NAME: 'ar',
    ERAS: const ['ق.م', 'م'],
    ERANAMES: const ['قبل الميلاد', 'ميلادي'],
    NARROWMONTHS: const [
      'ي',
      'ف',
      'م',
      'أ',
      'و',
      'ن',
      'ل',
      'غ',
      'س',
      'ك',
      'ب',
      'د',
    ],
    STANDALONENARROWMONTHS: const [
      'ي',
      'ف',
      'م',
      'أ',
      'و',
      'ن',
      'ل',
      'غ',
      'س',
      'ك',
      'ب',
      'د',
    ],
    MONTHS: const [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ],
    STANDALONEMONTHS: const [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ],
    SHORTMONTHS: const [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ],
    STANDALONESHORTMONTHS: const [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ],
    WEEKDAYS: const [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ],
    STANDALONEWEEKDAYS: const [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ],
    SHORTWEEKDAYS: const [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ],
    STANDALONESHORTWEEKDAYS: const [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ],
    NARROWWEEKDAYS: const ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'],
    STANDALONENARROWWEEKDAYS: const ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'],
    SHORTQUARTERS: const [
      'الربع الأول',
      'الربع الثاني',
      'الربع الثالث',
      'الربع الرابع',
    ],
    QUARTERS: const [
      'الربع الأول',
      'الربع الثاني',
      'الربع الثالث',
      'الربع الرابع',
    ],
    AMPMS: const ['ص', 'م'],
    DATEFORMATS: const [
      'EEEE، d MMMM y',
      'd MMMM y',
      'dd\u200f/MM\u200f/y',
      'd\u200f/M\u200f/y',
    ],
    TIMEFORMATS: const ['h:mm:ss a zzzz', 'h:mm:ss a z', 'h:mm:ss a', 'h:mm a'],
    DATETIMEFORMATS: const ['{1}، {0}', '{1}، {0}', '{1}، {0}', '{1}، {0}'],
    FIRSTDAYOFWEEK: 5,
    WEEKENDRANGE: const [4, 5],
    FIRSTWEEKCUTOFFDAY: 4,
  );

  static const Map<String, String> _arPatterns = {
    'd': 'd',
    'E': 'ccc',
    'EEEE': 'cccc',
    'LLL': 'LLL',
    'LLLL': 'LLLL',
    'M': 'L',
    'Md': 'd\u200f/M',
    'MEd': 'EEE، d\u200f/M',
    'MMM': 'LLL',
    'MMMd': 'd MMM',
    'MMMEd': 'EEE، d MMM',
    'MMMM': 'LLLL',
    'MMMMd': 'd MMMM',
    'MMMMEEEEd': 'EEEE، d MMMM',
    'QQQ': 'QQQ',
    'QQQQ': 'QQQQ',
    'y': 'y',
    'yM': 'M\u200f/y',
    'yMd': 'd\u200f/M\u200f/y',
    'yMEd': 'EEE، d\u200f/M\u200f/y',
    'yMMM': 'MMM y',
    'yMMMd': 'd MMM y',
    'yMMMEd': 'EEE، d MMM y',
    'yMMMM': 'MMMM y',
    'yMMMMd': 'd MMMM y',
    'yMMMMEEEEd': 'EEEE، d MMMM y',
    'yQQQ': 'QQQ y',
    'yQQQQ': 'QQQQ y',
    'H': 'HH',
    'Hm': 'HH:mm',
    'Hms': 'HH:mm:ss',
    'j': 'h\u202fa',
    'jm': 'h:mm a',
    'jms': 'h:mm:ss a',
    'jmv': 'h:mm a v',
    'jmz': 'h:mm a z',
    'jz': 'h\u202fa z',
    'm': 'm',
    'ms': 'mm:ss',
    's': 's',
    'v': 'v',
    'z': 'z',
    'zzzz': 'zzzz',
    'ZZZZ': 'ZZZZ',
  };

  /// Called during DI bootstrap, before localized date formatting is needed.
  ///
  /// Initializes only the app's supported locales (`ar`, `en`, `en_US`) to avoid
  /// synchronously evaluating `intl`'s all-locale symbol map on the UI thread.
  static Future<void> initialize() async {
    if (_initialized) return;
    initializeDateFormattingCustom(
      locale: 'en',
      symbols: _enSymbols,
      patterns: en_USPatterns,
    );
    initializeDateFormattingCustom(
      locale: 'en_US',
      symbols: en_USSymbols,
      patterns: en_USPatterns,
    );
    initializeDateFormattingCustom(
      locale: 'ar',
      symbols: _arSymbols,
      patterns: _arPatterns,
    );
    _initialized = true;
  }

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
