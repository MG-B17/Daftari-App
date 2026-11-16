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
  String get splashTagline => 'دفتر الآجل لمحلك';

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

  @override
  String get onboardingTitle1 => 'سجّل الآجل في ثوانٍ';

  @override
  String get onboardingDescription1 =>
      'اكتب حساب أي زبون بضغطة زر واحدة بدون تعقيد ولا ورق يضيع.';

  @override
  String get onboardingTitle2 => 'اعرف كل عميل';

  @override
  String get onboardingDescription2 =>
      'تابع حسابات زبائنك وإجمالي الآجل والسداد بوضوح في أي وقت.';

  @override
  String get onboardingTitle3 => 'بياناتك آمنة';

  @override
  String get onboardingDescription3 =>
      'يعمل بدون إنترنت بالكامل، مع إمكانية النسخ الاحتياطي السحابي لاحقاً.';

  @override
  String get onboardingSkip => 'تخطي';

  @override
  String get onboardingNext => 'التالي';

  @override
  String get onboardingStart => 'ابدأ الآن';

  @override
  String onboardingPageLabel(int page, int total, String title) {
    return 'الصفحة $page من $total: $title';
  }

  @override
  String get onboardingQuickEntry => 'تسجيل سريع';

  @override
  String get onboardingInstantPayment => 'سداد فوري';

  @override
  String get onboardingSaved => 'حفظ مباشر';

  @override
  String get onboardingSeconds => 'في 3 ثوانٍ فقط';

  @override
  String get onboardingSampleCustomer => 'عميل: عماد طه';

  @override
  String get onboardingSampleAmount => '250 ج.م';

  @override
  String get onboardingStorageError => 'تعذر حفظ تفضيلك. حاول مرة أخرى.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsAppearanceTitle => 'المظهر';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get settingsThemeSystem => 'النظام';

  @override
  String get settingsAppearanceCaption =>
      'الوضع الفاتح مصمم بألوان دفتر الحسابات التقليدي ليناسب ضوء الشمس';

  @override
  String get settingsLanguageTitle => 'لغة التطبيق';

  @override
  String get settingsLanguageArabic => 'العربية';

  @override
  String get settingsLanguageEnglish => 'الإنجليزية';

  @override
  String get settingsLanguageChange => 'اضغط لتغيير اللغة';

  @override
  String get settingsLanguagePickerTitle => 'اختر اللغة';

  @override
  String get settingsLanguagePickerSubtitle => 'حدد لغة عرض الواجهة والتقارير';

  @override
  String get settingsLanguageArabicDescription => 'واجهة كاملة باللغة العربية';

  @override
  String get settingsLanguageEnglishDescription => 'English user interface';

  @override
  String get settingsLanguageHint =>
      'يمكنك دائماً تغيير اللغة من الإعدادات لاحقاً';

  @override
  String get settingsLanguageBadgeArabic => 'ع';

  @override
  String get settingsLanguageBadgeEnglish => 'En';

  @override
  String get settingsAboutTitle => 'عن التطبيق';

  @override
  String get settingsVersionLabel => 'إصدار التطبيق';

  @override
  String get settingsVersionStable => 'مستقر';

  @override
  String get settingsStorageError => 'تعذر حفظ تفضيلك. حاول مرة أخرى.';
}
