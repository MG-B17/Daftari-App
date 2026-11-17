// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Daftari';

  @override
  String get splashTagline => 'Your shop’s credit ledger';

  @override
  String get foundationReady => 'Your ledger starts here';

  @override
  String get foundationDescription =>
      'The foundation is ready. Your customers and transactions will appear here in a later phase.';

  @override
  String get loading => 'Loading';

  @override
  String get emptyTitle => 'Nothing here yet';

  @override
  String get emptyMessage => 'New items will appear here.';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get errorMessage => 'Please try again.';

  @override
  String get retry => 'Retry';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get optional => 'Optional';

  @override
  String get requiredField => 'Required';

  @override
  String get onboardingTitle1 => 'Record credit in seconds';

  @override
  String get onboardingDescription1 =>
      'Log any customer balance with one tap—no complexity, no lost paper.';

  @override
  String get onboardingTitle2 => 'Know every customer';

  @override
  String get onboardingDescription2 =>
      'Track customer balances, total credit, and payments clearly anytime.';

  @override
  String get onboardingTitle3 => 'Your data is safe';

  @override
  String get onboardingDescription3 =>
      'Works completely offline, with optional cloud backup whenever you choose.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get Started';

  @override
  String onboardingPageLabel(int page, int total, String title) {
    return 'Page $page of $total: $title';
  }

  @override
  String get onboardingQuickEntry => 'Quick entry';

  @override
  String get onboardingInstantPayment => 'Instant payment';

  @override
  String get onboardingSaved => 'Saved instantly';

  @override
  String get onboardingSeconds => 'In just 3 seconds';

  @override
  String get onboardingSampleCustomer => 'Customer: Emad Taha';

  @override
  String get onboardingSampleAmount => 'EGP 250';

  @override
  String get onboardingStorageError =>
      'Couldn\'t save your preference. Please try again.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearanceTitle => 'Appearance';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsAppearanceCaption =>
      'The light paper theme is designed to suit traditional ledgers in sunlight.';

  @override
  String get settingsLanguageTitle => 'App language';

  @override
  String get settingsLanguageArabic => 'Arabic';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChange => 'Tap to change the language';

  @override
  String get settingsLanguagePickerTitle => 'Choose language';

  @override
  String get settingsLanguagePickerSubtitle =>
      'Choose the interface display language';

  @override
  String get settingsLanguageArabicDescription => 'Complete Arabic interface';

  @override
  String get settingsLanguageEnglishDescription => 'English user interface';

  @override
  String get settingsLanguageHint =>
      'You can always change the language later from Settings.';

  @override
  String get settingsLanguageBadgeArabic => 'ع';

  @override
  String get settingsLanguageBadgeEnglish => 'En';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get settingsVersionLabel => 'App version';

  @override
  String get settingsVersionStable => 'Stable';

  @override
  String get settingsStorageError =>
      'Couldn\'t save your preference. Please try again.';

  @override
  String get customersTitle => 'Customers';

  @override
  String get customersHome => 'Home';

  @override
  String get customerNewTitle => 'New customer';

  @override
  String get customerEditTitle => 'Edit customer';

  @override
  String get customerDetailsTitle => 'Customer details';

  @override
  String get customerFormHeading => 'A new page in your ledger';

  @override
  String get customerFormDescription =>
      'Record customer details to keep their account organized.';

  @override
  String get customerImport => 'Import from contacts';

  @override
  String get customerImportDescription => 'Choose a contact to save time';

  @override
  String get customerName => 'Customer name';

  @override
  String get customerNameHint => 'Enter the customer name';

  @override
  String get customerPhone => 'Mobile number';

  @override
  String get customerPhoneHint => 'Enter the mobile number';

  @override
  String get customerNotes => 'Note or address';

  @override
  String get customerNotesHint => 'Add a note or address';

  @override
  String get customerSave => 'Save customer';

  @override
  String get customerBalance => 'Current outstanding balance';

  @override
  String get customerCall => 'Call';

  @override
  String get customerCallError => 'Could not open the phone app.';

  @override
  String get customerEdit => 'Edit customer';

  @override
  String get customerNotFound => 'Customer not found';

  @override
  String get customersSearch => 'Search by name or phone...';

  @override
  String get customersAll => 'All';

  @override
  String get customersOwes => 'Owes';

  @override
  String get customersSettled => 'Settled';

  @override
  String get customersAdd => 'New customer';

  @override
  String get customersAddFirst => 'Add first customer';

  @override
  String get customersEmptyBadge => 'Your notebook is still new';

  @override
  String get customersEmptyTitle => 'No customers yet';

  @override
  String get customersEmptyMessage =>
      'Add your first customer and start recording credit and payments easily.';

  @override
  String get customersNoResults => 'No customers match your search.';

  @override
  String get customersTotalDebt => 'Total debt';

  @override
  String customersCount(int count, int owing) {
    return '$count customers • $owing owe a balance';
  }

  @override
  String get customersSample1 => 'Mohamed Abdel Fattah';

  @override
  String get customersSample2 => 'Ahmed El Shenawy';

  @override
  String get customersSample3 => 'Sameh the grocer';

  @override
  String get customersSample4 => 'Hussein the carpenter';

  @override
  String get customersSample5 => 'Umm Karim';

  @override
  String get customersSample6 => 'Ibrahim the blacksmith';

  @override
  String get customersSample7 => 'Ali the plumber';

  @override
  String get customersComingSoon => 'Coming in the next task';
}
