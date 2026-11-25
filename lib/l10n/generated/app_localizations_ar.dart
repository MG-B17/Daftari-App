// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get securityTitle => 'الأمان';

  @override
  String get securityBrandCaption => 'دفتري • حماية الدفتر';

  @override
  String get securityPinHelper => 'أدخل 4 أرقام للمتابعة';

  @override
  String get securityClearAll => 'مسح الكل';

  @override
  String get securityPreview =>
      'معاينة للواجهة فقط — التطبيق غير مقفل. رمز التجربة: 1234.';

  @override
  String get securityPin => 'رمز قفل التطبيق';

  @override
  String get securityPinDescription => 'احمِ دفترك برمز من 4 أرقام';

  @override
  String get securityChangePin => 'تغيير رمز القفل';

  @override
  String get securityBiometrics => 'الفتح بالبصمة';

  @override
  String get securityBiometricsDescription => 'استخدم بصمة الإصبع أو الوجه';

  @override
  String get securityAutoLock => 'القفل التلقائي';

  @override
  String get securityImmediate => 'فورًا';

  @override
  String get securityOneMinute => 'بعد دقيقة';

  @override
  String get securityFiveMinutes => 'بعد 5 دقائق';

  @override
  String get securityUnlockTitle => 'أدخل الرقم السري';

  @override
  String get securityUnlockSubtitle =>
      'لحماية حسابات الزبائن والديون من أعين المتطفلين';

  @override
  String get securitySetupTitle => 'إنشاء رمز القفل';

  @override
  String get securitySetupSubtitle => 'اختر رمزًا من 4 أرقام لحماية دفترك';

  @override
  String get securityConfirmTitle => 'تأكيد رمز القفل';

  @override
  String get securityConfirmSubtitle => 'أدخل نفس الرمز مرة أخرى';

  @override
  String get securityChangeTitle => 'تغيير رمز القفل';

  @override
  String get securityDisableTitle => 'إيقاف رمز القفل';

  @override
  String get securityCurrentPin => 'أدخل رمز القفل الحالي للمتابعة';

  @override
  String get securityResetTitle => 'إعادة تعيين رمز القفل';

  @override
  String get securityPinError => 'الرمز غير متطابق. حاول مرة أخرى.';

  @override
  String get securityForgotPin => 'نسيت رمز القفل؟';

  @override
  String get securityBiometricAction => 'الفتح بالبصمة';

  @override
  String get securityRecoveryTitle => 'استعادة الوصول';

  @override
  String get securityRecoveryGuidance =>
      'تتطلب الاستعادة قفل شاشة الجهاز. بدونه، لا يمكن إعادة تعيين الوصول إلا بإعادة تثبيت التطبيق، وقد يؤدي ذلك إلى فقدان دفتر الديون المحلي نهائيًا. لم تتغير أي بيانات.';

  @override
  String get securityRecoveryPreview =>
      'معاينة الاستعادة بقفل الجهاز؟ لن تُجرى مصادقة فعلية ولن يتغير أي رمز حقيقي.';

  @override
  String get securityBiometricPreview =>
      'معاينة الفتح بالبصمة؟ لن تُجرى مصادقة فعلية.';

  @override
  String get securityComplete => 'تم تحديث رمز القفل';

  @override
  String get securityCompleteDescription => 'تم حفظ إعدادات الأمان.';

  @override
  String get securityStorageError =>
      'تعذرت قراءة بيانات الأمان أو حفظها بأمان. الوصول مقفل. أعد تشغيل التطبيق وحاول مجددًا. لم يُحذف دفتر الديون.';

  @override
  String get securityAuthUnavailable =>
      'أُلغيت المصادقة أو تعذرت. حاول مجددًا أو استخدم رمز قفل التطبيق.';

  @override
  String securityCooldown(int seconds) {
    return 'محاولات كثيرة. حاول مجددًا بعد $seconds ثانية.';
  }

  @override
  String get securityDone => 'تم';

  @override
  String get securityDeleteDigit => 'حذف آخر رقم';

  @override
  String securityPinProgress(int count) {
    return 'تم إدخال $count من 4 أرقام';
  }

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

  @override
  String get authLoginTitle => 'تسجيل الدخول';

  @override
  String get authRegisterTitle => 'إنشاء حساب جديد';

  @override
  String get authForgotTitle => 'استعادة كلمة المرور';

  @override
  String get authVerifyTitle => 'تأكيد البريد الإلكتروني';

  @override
  String get authUpdateTitle => 'كلمة مرور جديدة';

  @override
  String get authLoginHeading => 'احم بياناتك من الضياع';

  @override
  String get authLoginSubtitle =>
      'اربط دفترك المحلي بحسابك لضمان عدم ضياع حسابات الزبائن والديون في حالة تغير أو فقدان الهاتف.';

  @override
  String get authRegisterHeading => 'احم بياناتك من الضياع';

  @override
  String get authRegisterSubtitle =>
      'أنشئ حسابك لربط دفترك المحلي وإتاحة النسخ الاحتياطي الآمن الاختياري واستعادة بياناتك حتى لو فقدت الهاتف.';

  @override
  String get authForgotHeading => 'نسيت كلمة المرور؟';

  @override
  String get authForgotSubtitle =>
      'أدخل بريدك الإلكتروني وسنرسل لك رابطًا لإعادة تعيين كلمة المرور.';

  @override
  String get authVerifyHeading => 'تحقق من بريدك';

  @override
  String authVerifySubtitle(String email) {
    return 'أرسلنا رابط تأكيد إلى $email. افتحه لتفعيل حسابك.';
  }

  @override
  String get authVerifyGenericSubtitle =>
      'افتح رابط التأكيد في بريدك الإلكتروني لتفعيل حسابك.';

  @override
  String get authUpdateHeading => 'اختر كلمة مرور جديدة';

  @override
  String get authUpdateSubtitle => 'اختر كلمة مرور جديدة لحسابك.';

  @override
  String get authSecureBadge => 'تشفير آمن';

  @override
  String get authEmail => 'البريد الإلكتروني';

  @override
  String get authEmailHint => 'example@gmail.com';

  @override
  String get authPassword => 'كلمة المرور';

  @override
  String get authPasswordHint => 'أدخل كلمة المرور';

  @override
  String get authShowPassword => 'إظهار كلمة المرور';

  @override
  String get authHidePassword => 'إخفاء كلمة المرور';

  @override
  String get authForgotPassword => 'نسيت كلمة السر؟';

  @override
  String get authSignIn => 'تسجيل الدخول';

  @override
  String get authNoAccount => 'ليس لديك حساب؟';

  @override
  String get authCreateAccount => 'إنشاء حساب جديد';

  @override
  String get authShopName => 'اسم المحل / التاجر';

  @override
  String get authShopNameHint => 'مثال: بقالة الأمانة أو أبو عمر';

  @override
  String get authShopNameViewerHint => 'يظهر في كشف الحساب';

  @override
  String get authConfirmPassword => 'تأكيد كلمة المرور';

  @override
  String get authRegisterAction => 'إنشاء حساب وحفظ الدفتر';

  @override
  String get authHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get authSignInLink => 'تسجيل الدخول';

  @override
  String get authRegisterConsent =>
      'بإنشاء الحساب، أنت توافق على شروط الاستخدام وسياسة حماية البيانات. خصوصية الدفتر: بياناتك تظل ملكًا لك وحدك.';

  @override
  String get authOfflineNoteTitle => 'دفترك يعمل بدون إنترنت دائمًا';

  @override
  String get authOfflineNote =>
      'التسجيل يتيح لك النسخ الاحتياطي الآمن الاختياري للمساعدة في حماية دفترك عند سرقة الهاتف أو تلفه.';

  @override
  String get authContinueOffline => 'المتابعة كدفتر محلي (لاحقًا)';

  @override
  String get authContinueOfflineHint =>
      'يمكنك متابعة استخدام الدفتر محليًا والنسخ لاحقًا.';

  @override
  String get authLoginMockNotice => 'معاينة فقط — تسجيل الدخول غير متاح بعد.';

  @override
  String get authRegisterMockNotice =>
      'معاينة فقط — إنشاء الحساب غير متاح بعد.';

  @override
  String get authSendResetLink => 'إرسال رابط الاستعادة';

  @override
  String get authResetSentTitle => 'تحقق من بريدك';

  @override
  String authResetSentMessage(String email) {
    return 'أرسلنا رابط إعادة تعيين كلمة المرور إلى $email.';
  }

  @override
  String get authBackToLogin => 'العودة لتسجيل الدخول';

  @override
  String get authForgotMockNotice => 'معاينة فقط — لن يُرسل أي بريد.';

  @override
  String get authResendVerification => 'إعادة إرسال رابط التأكيد';

  @override
  String get authResendSent => 'تم إرسال رابط التأكيد مرة أخرى.';

  @override
  String get authVerifiedAction => 'تحققت من بريدي';

  @override
  String get authVerifyMockNotice => 'معاينة فقط — تأكيد البريد غير متاح بعد.';

  @override
  String get authNewPassword => 'كلمة المرور الجديدة';

  @override
  String get authUpdatePasswordAction => 'حفظ كلمة المرور';

  @override
  String get authUpdateMockNotice =>
      'معاينة فقط — تحديث كلمة المرور غير متاح بعد.';

  @override
  String get authPasswordMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get authShopNameRequired => 'أدخل اسم المحل';

  @override
  String get authLinkDialogTitle => 'ربط الدفتر بحسابك؟';

  @override
  String get authLinkDialogMessage =>
      'سيتم ربط بيانات الدفتر المحلي على هذا الجهاز بحسابك. لن يتم رفع أي بيانات الآن، وتبقى بياناتك على جهازك. بعد الربط، لا يمكن استخدام دفتر هذا الجهاز إلا مع هذا الحساب.';

  @override
  String get authLinkDialogConfirm => 'ربط الدفتر';

  @override
  String get authAccountTitle => 'الحساب';

  @override
  String get authAccountSignedOutTitle => 'لم تسجل الدخول';

  @override
  String get authAccountSignedOutDescription =>
      'اربط دفترك بحساب لضمان عدم ضياع البيانات.';

  @override
  String get authAccountSignIn => 'تسجيل الدخول';

  @override
  String get authAccountCreate => 'إنشاء حساب';

  @override
  String get authAccountLinkedTitle => 'تم ربط الدفتر';

  @override
  String authAccountLinkedTo(String email) {
    return 'مرتبط بـ $email';
  }

  @override
  String get authAccountVerified => 'مؤكد';

  @override
  String get authAccountEmailUnverified => 'البريد غير مؤكد';

  @override
  String get authAccountSignOut => 'تسجيل الخروج';

  @override
  String get authAccountLocalOnly => 'بياناتك محلية على هذا الجهاز';

  @override
  String get authAccountMockNotice => 'معاينة فقط — الحساب غير متصل بعد.';

  @override
  String get authAccountSignOutMessage =>
      'تسجيل الخروج؟ لن يتم حذف بيانات الدفتر المحلي.';

  @override
  String get authErrorAccountMismatch =>
      'دفتر هذا الجهاز مرتبط بحساب آخر. سجّل الدخول بالحساب الأصلي للمتابعة.';

  @override
  String get authErrorAuth =>
      'تعذر تسجيل الدخول. تأكد من البريد الإلكتروني وكلمة المرور وحاول مرة أخرى.';

  @override
  String get authErrorNetwork =>
      'تعذر الاتصال. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';

  @override
  String get authErrorUnconfigured =>
      'تسجيل الدخول غير مفعّل في هذه النسخة. يواصل دفترك العمل محليًا.';

  @override
  String get authErrorGeneric => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get authPasswordUpdated => 'تم تحديث كلمة المرور بنجاح.';

  @override
  String get authEmailNotVerifiedYet =>
      'لم يتم تأكيد بريدك الإلكتروني بعد. افتح الرابط في بريدك وحاول مرة أخرى.';

  @override
  String get authSignedOutSuccess =>
      'تم تسجيل الخروج. بيانات دفترك المحلي محفوظة على هذا الجهاز.';

  @override
  String get authLinkedSuccess => 'تم ربط الدفتر بحسابك.';

  @override
  String get backupSectionTitle => 'النسخ الاحتياطي السحابي';

  @override
  String get backupSyncStatusTitle => 'حالة المزامنة السحابية';

  @override
  String get backupStatusNeverBackedUp => 'لم يتم النسخ بعد';

  @override
  String get backupStatusPending => 'تغييرات بانتظار النسخ';

  @override
  String get backupStatusRunning => 'جارٍ النسخ…';

  @override
  String get backupStatusFailed => 'فشل النسخ';

  @override
  String get backupStatusUpToDate => 'متصل وآمن';

  @override
  String backupLastConfirmed(String day, String time) {
    return 'آخر نسخة: $day $time';
  }

  @override
  String get backupNeverConfirmed => 'لا توجد نسخة بعد';

  @override
  String backupPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغيير بانتظار النسخ',
      many: '$count تغييرًا بانتظار النسخ',
      few: '$count تغييرات بانتظار النسخ',
      two: 'تغييران بانتظار النسخ',
      one: 'تغيير واحد بانتظار النسخ',
      zero: 'لا توجد تغييرات معلقة',
    );
    return '$_temp0';
  }

  @override
  String get backupFailedHint =>
      'لم تكتمل المحاولة الأخيرة. نسختك السابقة محفوظة.';

  @override
  String get backupFailedFirstHint =>
      'لم تكتمل محاولة النسخ. دفترك المحلي محفوظ بأمان على هذا الجهاز.';

  @override
  String get backupPreviewBanner =>
      'معاينة — النسخ الاحتياطي السحابي غير متصل بعد.';

  @override
  String get backupAccountSignedOutTitle => 'غير مسجل الدخول';

  @override
  String get backupAccountSignedOutSubtitle =>
      'سجّل الدخول من إعدادات الحساب لتفعيل النسخ السحابي.';

  @override
  String get backupNowAction => 'نسخ احتياطي الآن';

  @override
  String get backupNowTitle => 'حفظ نسخة فورية للسحابة';

  @override
  String get backupNowSubtitle => 'تأمين كافة الديون والتسديدات الآن';

  @override
  String get backupManageTitle => 'إدارة النسخ الاحتياطي';

  @override
  String get backupManageSubtitle => 'جدول النسخ وحالته';

  @override
  String get backupScreenTitle => 'إعدادات النسخ الاحتياطي';

  @override
  String get backupActiveAccount => 'حساب نشط';

  @override
  String get backupScheduleTitle => 'جدول النسخ الاحتياطي';

  @override
  String get backupScheduleDaily => 'يوميًا';

  @override
  String get backupScheduleWeekly => 'أسبوعيًا';

  @override
  String get backupScheduleMonthly => 'شهريًا';

  @override
  String get backupScheduleCaption =>
      'اختر عدد مرات النسخ التلقائي عندما يسمح أندرويد بذلك.';

  @override
  String get backupMockNotice => 'معاينة فقط — النسخ الاحتياطي غير متاح بعد.';

  @override
  String get backupRestoreAction => 'استعادة البيانات السحابية';

  @override
  String get backupInactiveDeviceHint =>
      'أصبح هاتف آخر هو جهاز النسخ الاحتياطي النشط لهذا الحساب. يظل دفترك المحلي متاحًا على هذا الهاتف بدون إنترنت، أو يمكنك الاستعادة ونقل صلاحية النسخ الاحتياطي إلى هنا.';

  @override
  String get restoreScreenTitle => 'استعادة النسخة السحابية';

  @override
  String get restoreCloudSnapshotTitle => 'النسخة السحابية المؤكدة';

  @override
  String restoreConfirmedAt(String day, String time) {
    return 'نسخة مؤكدة: $day $time';
  }

  @override
  String restoreCustomersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عميل',
      many: '$count عميلًا',
      few: '$count عملاء',
      two: 'عميلان',
      one: 'عميل واحد',
      zero: '0 عملاء',
    );
    return '$_temp0';
  }

  @override
  String restoreTransactionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حركة',
      many: '$count حركة',
      few: '$count حركات',
      two: 'حركتان',
      one: 'حركة واحدة',
      zero: '0 حركات',
    );
    return '$_temp0';
  }

  @override
  String restoreHistoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سجل محذوف أو تدقيق',
      many: '$count سجلًا محذوفًا أو تدقيق',
      few: '$count سجلات محذوفة أو تدقيق',
      two: 'سجلان محذوفان أو تدقيق',
      one: 'سجل محذوف أو تدقيق واحد',
      zero: '0 سجلات محذوفة أو تدقيق',
    );
    return '$_temp0';
  }

  @override
  String get restoreZeroRowsSnapshotNote =>
      'تحتوي هذه النسخة المؤكدة على دفتر فارغ (0 سجلات).';

  @override
  String get restoreConsequenceTitle => 'ماذا سيحدث على هذا الهاتف';

  @override
  String get restoreConsequenceTakeover =>
      'سيستلم هذا الهاتف الدفتر السحابي المؤكد ويصبح الهاتف النشط للنسخ الاحتياطي لهذا الحساب. يحتفظ الهاتف السابق بدفتره المحلي بدون إنترنت، لكنه لن يرفع نسخًا احتياطية سحابية بعد الآن.';

  @override
  String get restoreConsequenceSameDevice =>
      'هذا الهاتف هو بالفعل الهاتف النشط للنسخ الاحتياطي لهذا الحساب. تؤدي الاستعادة إلى تحميل الدفتر السحابي المؤكد على هذا الهاتف دون تغيير صلاحية جهاز النسخ الاحتياطي.';

  @override
  String get restorePreviousPhonePendingWarning =>
      'أي تغييرات لا تزال معلقة ولم تُرفع من الهاتف السابق ليست ضمن هذه النسخة المؤكدة وتظل متاحة على ذلك الهاتف فقط.';

  @override
  String get restoreLocalEmptyTitle => 'دفتر هذا الهاتف فارغ';

  @override
  String get restoreLocalEmptyMessage =>
      'لا يوجد عملاء أو حركات أو سجل تدقيق محلي على هذا الهاتف.';

  @override
  String get restoreLocalPopulatedTitle => 'يوجد دفتر محلي حالي على هذا الهاتف';

  @override
  String get restoreLocalPopulatedWarning =>
      'ستؤدي الاستعادة إلى استبدال جميع السجلات المحلية على هذا الهاتف بالنسخة السحابية المؤكدة. سيُطلب منك تأكيد ثانٍ.';

  @override
  String get restoreAndTransferAction =>
      'استعادة الدفتر ونقل النسخ لهذا الهاتف';

  @override
  String get restoreOnlyAction => 'استعادة النسخة السحابية';

  @override
  String get restoreConfirmTakeoverTitle =>
      'تأكيد الاستعادة ونقل الجهاز النشط؟';

  @override
  String get restoreConfirmTakeoverMessage =>
      'أنت على وشك استعادة النسخة السحابية المؤكدة إلى هذا الهاتف وجعل هذا الهاتف جهاز النسخ الاحتياطي النشط لحسابك. سيتوقف رفع النسخ السحابية من الهاتف السابق، وأي تغييرات لا تزال معلقة على الهاتف السابق ستظل متاحة هناك فقط.';

  @override
  String get restoreConfirmTakeoverButton => 'تأكيد الاستعادة والنقل';

  @override
  String get restoreConfirmSameDeviceTitle => 'تأكيد الاستعادة السحابية؟';

  @override
  String get restoreConfirmSameDeviceMessage =>
      'أنت على وشك استعادة النسخة السحابية المؤكدة على هذا الهاتف النشط. سيتم استعادة السجلات المشمولة في آخر نسخة مؤكدة على الخادم فقط.';

  @override
  String get restoreConfirmSameDeviceButton => 'تأكيد الاستعادة';

  @override
  String get restoreReplacementConfirmTitle =>
      'استبدال الدفتر المحلي على هذا الهاتف؟';

  @override
  String get restoreReplacementConfirmMessage =>
      'يحتوي هذا الهاتف بالفعل على سجلات دفتر محلي. سيؤدي التأكيد إلى استبدال الدفتر المحلي على هذا الهاتف نهائيًا بالنسخة السحابية المؤكدة.';

  @override
  String get restoreReplacementLocalSummaryTitle =>
      'السجلات المحلية التي سيتم استبدالها على هذا الهاتف';

  @override
  String get restoreReplacementConfirmButton => 'استبدال الدفتر المحلي';

  @override
  String get restoreSignedOutTitle => 'سجّل الدخول لاستعادة النسخة السحابية';

  @override
  String get restoreSignedOutMessage =>
      'سجّل الدخول إلى حسابك من إعدادات الحساب للتحقق من نسختك السحابية المؤكدة واستعادتها.';

  @override
  String get restoreEmailUnverifiedTitle => 'أكد بريدك الإلكتروني أولاً';

  @override
  String get restoreEmailUnverifiedMessage =>
      'أكد عنوان البريد الإلكتروني لحسابك قبل استعادة النسخة السحابية.';

  @override
  String get restoreAccountMismatchTitle => 'الدفتر مرتبط بحساب آخر';

  @override
  String get restoreAccountMismatchMessage =>
      'دفتر هذا الهاتف المحلي مرتبط بحساب آخر ولا يمكن استبداله بنسخة احتياطية من هذا الحساب. سجّل الدخول بالحساب الأصلي لاستخدام هذا الدفتر.';

  @override
  String get restoreOfflineTitle => 'لا يوجد اتصال بالإنترنت';

  @override
  String get restoreOfflineMessage =>
      'اتصل بالإنترنت لمعاينة واستعادة نسختك السحابية المؤكدة. يظل دفترك المحلي على هذا الهاتف سليمًا ومتاحًا بدون إنترنت.';

  @override
  String get restoreMissingBackupTitle => 'لا توجد نسخة احتياطية سحابية';

  @override
  String get restoreMissingBackupMessage =>
      'لا توجد نسخة احتياطية سحابية مؤكدة لهذا الحساب بعد. قم بنسخ دفترك احتياطيًا من هاتفك النشط أولاً ثم حاول مرة أخرى.';

  @override
  String get restoreInterruptedTitle => 'إكمال الاستعادة المتوقفة';

  @override
  String get restoreInterruptedMessage =>
      'توقفت عملية استعادة سحابية ونقل للجهاز قبل اكتمالها. دفترك المحلي الحالي لا يزال سليمًا. استأنف العملية لإكمال تثبيت النسخة المؤكدة بأمان.';

  @override
  String get restoreInterruptedUploadsBlockedNote =>
      'يظل رفع النسخ السحابية على هذا الهاتف متوقفًا مؤقتًا حتى يكتمل الاستئناف.';

  @override
  String get restoreResumeAction => 'استئناف الاستعادة';

  @override
  String get restoreCloudVersionChangedNotice =>
      'تم اكتشاف نسخة سحابية أحدث أو تغيير في الجهاز النشط. راجع تفاصيل النسخة المحدثة وأكّد مرة أخرى.';

  @override
  String get restoreLocalLedgerChangedNotice =>
      'تم تسجيل تغييرات في الدفتر المحلي بعد المعاينة. راجع الأعداد المحلية المحدثة وأكّد الاستبدال مرة أخرى.';

  @override
  String get restoreCompletedTitle => 'تمت استعادة الدفتر السحابي';

  @override
  String get restoreCompletedTransferredMessage =>
      'تم تثبيت الدفتر السحابي المؤكد على هذا الهاتف، وسيتم رفع النسخ الاحتياطية السحابية المستقبلية من هذا الهاتف.';

  @override
  String get restoreCompletedSameDeviceMessage =>
      'تم تثبيت الدفتر السحابي المؤكد على هذا الهاتف.';

  @override
  String get restoreDoneAction => 'العودة لإعدادات النسخ الاحتياطي';
}
