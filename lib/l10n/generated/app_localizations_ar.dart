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

  @override
  String get customersTitle => 'العملاء';

  @override
  String get customersHome => 'الرئيسية';

  @override
  String get customerNewTitle => 'عميل جديد';

  @override
  String get customerEditTitle => 'تعديل العميل';

  @override
  String get customerDetailsTitle => 'تفاصيل العميل';

  @override
  String get customerFormHeading => 'صفحة دفتر جديدة';

  @override
  String get customerFormDescription => 'سجل بيانات الزبون بدقة لضبط الحساب.';

  @override
  String get customerImport => 'سحب من جهات الاتصال';

  @override
  String get customerImportDescription =>
      'اختيار سريع من سجل هاتفك لتوفير وقت الكتابة';

  @override
  String get customerName => 'اسم العميل';

  @override
  String get customerNameHint => 'اكتب اسم العميل';

  @override
  String get customerPhone => 'رقم الموبايل';

  @override
  String get customerPhoneHint => 'اكتب رقم الموبايل';

  @override
  String get customerNotes => 'ملاحظة أو عنوان';

  @override
  String get customerNotesHint => 'أضف ملاحظة أو عنوان';

  @override
  String get customerSave => 'حفظ العميل في الدفتر';

  @override
  String get customerBalance => 'إجمالي الحساب المستحق حالياً';

  @override
  String get customerCall => 'اتصال';

  @override
  String get customerCallError => 'تعذر فتح تطبيق الهاتف.';

  @override
  String get customerEdit => 'تعديل العميل';

  @override
  String get customerNotFound => 'العميل غير موجود';

  @override
  String get customersSearch => 'ابحث بالاسم أو رقم الهاتف...';

  @override
  String get customersAll => 'الكل';

  @override
  String get customersOwes => 'عليهم رصيد';

  @override
  String get customersSettled => 'خالص';

  @override
  String get customersAdd => 'عميل جديد';

  @override
  String get customersAddFirst => 'أضف أول عميل';

  @override
  String get customersEmptyBadge => 'دفترك أبيض ولسه جديد';

  @override
  String get customersEmptyTitle => 'لسه مفيش عملاء مسجلين';

  @override
  String get customersEmptyMessage =>
      'سجل أول زبون عندك وابدأ تدوين الديون والسداد بسهولة.';

  @override
  String get customersNoResults => 'لا يوجد عملاء يطابقون البحث.';

  @override
  String get customersTotalDebt => 'مجموع الديون';

  @override
  String customersCount(int count, int owing) {
    return 'إجمالي $count عملاء • $owing عليهم رصيد مستحق';
  }

  @override
  String get customersSample1 => 'محمد عبد الفتاح';

  @override
  String get customersSample2 => 'أحمد الشناوي (ورشة)';

  @override
  String get customersSample3 => 'سامح البقال';

  @override
  String get customersSample4 => 'حسين النجار';

  @override
  String get customersSample5 => 'أم كريم (الخضار)';

  @override
  String get customersSample6 => 'إبراهيم الحداد';

  @override
  String get customersSample7 => 'علي السباك';

  @override
  String get customersComingSoon => 'قريباً في المهمة القادمة';

  @override
  String get customerErrorDatabase =>
      'تعذر الوصول إلى بيانات العملاء. حاول مرة أخرى.';

  @override
  String get customerErrorStorage => 'تعذر الوصول إلى التخزين. حاول مرة أخرى.';

  @override
  String get customerErrorNetwork => 'حدث خطأ في الشبكة. حاول مرة أخرى.';

  @override
  String get customerErrorAuth => 'فشل تسجيل الدخول. حاول مرة أخرى.';

  @override
  String get customerErrorPicker =>
      'تعذر فتح جهات الاتصال. يمكنك إدخال البيانات يدوياً.';

  @override
  String get customerErrorValidation => 'أدخل الاسم ورقم موبايل مصري صحيح.';

  @override
  String get customerErrorUnexpected => 'حدث خطأ. حاول مرة أخرى.';

  @override
  String get customersSort => 'ترتيب العملاء';

  @override
  String get customersSortName => 'الاسم';

  @override
  String get customersSortBalance => 'أعلى رصيد';

  @override
  String get customersSortRecent => 'الأحدث إضافة';

  @override
  String get customerDelete => 'حذف العميل';

  @override
  String get customerDeleteMessage =>
      'هل تريد حذف العميل؟ سيبقى سجل حسابه محفوظاً.';

  @override
  String customerDeleteBalanceMessage(String balance) {
    return 'على هذا العميل رصيد قدره $balance. هل تريد حذفه؟ سيبقى سجل حسابه محفوظاً.';
  }

  @override
  String get transactionNew => 'حركة جديدة';

  @override
  String get transactionEdit => 'تعديل الحركة';

  @override
  String get transactionCredit => 'عليه (دين / آجل)';

  @override
  String get transactionPayment => 'سدد (قبض / سداد)';

  @override
  String get transactionCustomer => 'العميل';

  @override
  String get transactionChooseCustomer => 'اختر العميل';

  @override
  String get transactionChange => 'تغيير';

  @override
  String get transactionAmount => 'المبلغ المطلوب تقييده';

  @override
  String get transactionQuickAmounts => 'لوحة الأرقام السريعة';

  @override
  String get transactionDate => 'تاريخ الحركة';

  @override
  String get transactionNote => 'ملاحظة أو صنف البضاعة (اختياري)';

  @override
  String get transactionSave => 'حفظ الحركة في الدفتر';

  @override
  String get transactionMockNotice => 'للمعاينة فقط — لن تُحفظ الحركات.';

  @override
  String get transactionMockHistory => 'سجل تجريبي — ليس معاملات هذا العميل';

  @override
  String get transactionHistory => 'سجل المعاملات';

  @override
  String get transactionSampleCredit => 'مشتريات بقالة';

  @override
  String get transactionSamplePayment => 'دفعة نقدية';

  @override
  String get transactionBalance => 'الرصيد';

  @override
  String get transactionBackspace => 'حذف رقم';

  @override
  String get transactionSaveError =>
      'تعذر حفظ الحركة. تحقق من العميل والمبلغ وحاول مرة أخرى.';

  @override
  String get transactionNotFound => 'الحركة غير موجودة.';

  @override
  String transactionCount(int count) {
    return '$count حركات';
  }

  @override
  String get transactionHistoryEmpty => 'لا توجد حركات بعد.';

  @override
  String get transactionHistoryError =>
      'تعذر تحميل الحركات أو تعديلها. حاول مرة أخرى.';

  @override
  String get transactionBalanceUnavailable => 'الرصيد أكبر من أن يُعرض';

  @override
  String get transactionDeleteMessage =>
      'هل تريد حذف هذه الحركة؟ ستُحفظ قيمها السابقة في سجل التدقيق.';

  @override
  String transactionHistoryCount(int count) {
    return '$count حركات تجريبية';
  }

  @override
  String get transactionCreditBadge => 'عليه';

  @override
  String get transactionPaymentBadge => 'سدد';

  @override
  String get transactionEditAction => 'تعديل';

  @override
  String get transactionDeleteAction => 'حذف';

  @override
  String get transactionSampleCreditNote => 'مشتريات بقالة';

  @override
  String get transactionSamplePaymentNote => 'مقبوضات كاش';

  @override
  String get dashboardTitle => 'دفتر الحسابات';

  @override
  String get dashboardSubtitle => 'الرئيسية';

  @override
  String get dashboardGreetingCaption => 'صباح الخير يا معلم،';

  @override
  String get dashboardWelcome => 'أهلاً، محلك';

  @override
  String get dashboardTotalOwed => 'إجمالي اللي على العملاء';

  @override
  String dashboardDebtorCount(int count) {
    return '$count عميل عليهم رصيد مستحق';
  }

  @override
  String get dashboardTodayCollections => 'تحصيلات اليوم';

  @override
  String get dashboardRegisterTransaction => 'تسجيل حركة';

  @override
  String get dashboardNewCustomer => 'عميل جديد';

  @override
  String get dashboardTopDebtors => 'أكبر المدينين';

  @override
  String get dashboardViewAll => 'عرض الكل';

  @override
  String get dashboardRecentActivity => 'آخر الحركات';

  @override
  String get dashboardUpdatedLive => 'محدث لحظيًا';

  @override
  String dashboardActivityDate(String day, String time) {
    return '$day، $time';
  }

  @override
  String get dashboardTipTitle => 'دفترك مضبوط ومحمي';

  @override
  String get dashboardTipMessage =>
      'سجل كل قرش أول بأول عشان حسابك وحق زباينك ما يضيعش.';

  @override
  String get statementTitle => 'كشف حساب العميل';

  @override
  String get statementLoadError => 'تعذر تحميل كشف الحساب. حاول مرة أخرى.';

  @override
  String get statementShareError => 'تعذرت مشاركة كشف الحساب. حاول مرة أخرى.';

  @override
  String get statementCopyError => 'تعذر نسخ كشف الحساب. حاول مرة أخرى.';

  @override
  String get statementCopied => 'تم نسخ كشف الحساب';

  @override
  String get statementEmpty => 'لا توجد معاملات في هذه الفترة.';

  @override
  String get statementSettledHint => 'لا يوجد رصيد مستحق';

  @override
  String get statementCreditBalanceHint => 'رصيد لصالح العميل';

  @override
  String statementPeriodCredit(String amount) {
    return 'إجمالي الآجل للفترة: $amount';
  }

  @override
  String statementPeriodPayment(String amount) {
    return 'إجمالي السداد للفترة: $amount';
  }

  @override
  String get statementPreviewTitle => 'معاينة الرسالة قبل الإرسال للعميل';

  @override
  String get statementPreviewSubtitle =>
      'يمكنك مراجعة البنود والمبالغ قبل مشاركتها مع العميل.';

  @override
  String get statementMockNotice =>
      'كشف تجريبي — ليس من بيانات هذا العميل. التصفية والمشاركة والنسخ غير متاحة في هذه المعاينة.';

  @override
  String statementGeneratedAt(String date, String time) {
    return 'بتاريخ: $date • $time';
  }

  @override
  String get statementBalance => 'إجمالي الحساب المستحق (عليه)';

  @override
  String get statementBalanceHint => 'مطلوب سداد المبلغ أو دفعة منه';

  @override
  String get statementRangeAll => 'كل الفترات';

  @override
  String get statementRangeLast30Days => 'آخر 30 يوم';

  @override
  String get statementRangeThisMonth => 'هذا الشهر';

  @override
  String get statementRangeCustom => 'فترة مخصصة';

  @override
  String get statementEntriesTitle => 'حركات الحساب';

  @override
  String get statementFooter => 'شكرًا لتعاملكم معنا، نسعد بخدمتكم دائمًا.';

  @override
  String get statementWhatsApp => 'إرسال عبر واتساب';

  @override
  String get statementCopy => 'نسخ النص';

  @override
  String get statementShareHint =>
      'مشاركة صور كشف الحساب. اختر واتساب أو تطبيقًا آخر ثم أرسل.';

  @override
  String get statementImageTitle => 'كشف حساب';

  @override
  String get statementImageShare => 'مشاركة صورة كشف الحساب';

  @override
  String get statementImageFooter => 'تم إنشاء كشف الحساب بواسطة دفتري';

  @override
  String statementImagePage(int page, int total) {
    return '$page / $total';
  }

  @override
  String get statementShareWithCustomer => 'مشاركة كشف الحساب مع العميل';

  @override
  String get statementSampleCustomer => 'الحاج محمود الشناوي';

  @override
  String get statementSampleCredit1 => 'سكر وزيت كرتونة';

  @override
  String get statementSampleCredit2 => 'جبنة بيضاء 2 كجم';

  @override
  String get statementSampleCredit3 => 'طلبات تموين منزلية';

  @override
  String get statementSamplePayment1 => 'دفعة نقدية باليد';

  @override
  String get statementSamplePayment2 => 'تحويل فودافون كاش';
}
