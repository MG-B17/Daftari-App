// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'دفتري';

  @override
  String get foundationReady => 'دفترك يبدأ من هنا';

  @override
  String get foundationDescription =>
      'الأساس جاهز. سيظهر عملاؤك ومعاملاتك هنا في مرحلة لاحقة.';

  @override
  String get loading => 'جارٍ التحميل';

  @override
  String get emptyTitle => 'لا توجد بيانات بعد';

  @override
  String get emptyMessage => 'ستظهر العناصر الجديدة هنا.';

  @override
  String get errorTitle => 'حدث خطأ';

  @override
  String get errorMessage => 'يرجى المحاولة مرة أخرى.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get confirm => 'تأكيد';

  @override
  String get cancel => 'إلغاء';

  @override
  String get optional => 'اختياري';

  @override
  String get requiredField => 'مطلوب';
}
