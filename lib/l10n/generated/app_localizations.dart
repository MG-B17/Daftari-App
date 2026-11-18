import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Daftari'**
  String get appTitle;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Your shop’s credit ledger'**
  String get splashTagline;

  /// No description provided for @foundationReady.
  ///
  /// In en, this message translates to:
  /// **'Your ledger starts here'**
  String get foundationReady;

  /// No description provided for @foundationDescription.
  ///
  /// In en, this message translates to:
  /// **'The foundation is ready. Your customers and transactions will appear here in a later phase.'**
  String get foundationDescription;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyTitle;

  /// No description provided for @emptyMessage.
  ///
  /// In en, this message translates to:
  /// **'New items will appear here.'**
  String get emptyMessage;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Please try again.'**
  String get errorMessage;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Record credit in seconds'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDescription1.
  ///
  /// In en, this message translates to:
  /// **'Log any customer balance with one tap—no complexity, no lost paper.'**
  String get onboardingDescription1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Know every customer'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDescription2.
  ///
  /// In en, this message translates to:
  /// **'Track customer balances, total credit, and payments clearly anytime.'**
  String get onboardingDescription2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Your data is safe'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDescription3.
  ///
  /// In en, this message translates to:
  /// **'Works completely offline, with optional cloud backup whenever you choose.'**
  String get onboardingDescription3;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingStart;

  /// No description provided for @onboardingPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}: {title}'**
  String onboardingPageLabel(int page, int total, String title);

  /// No description provided for @onboardingQuickEntry.
  ///
  /// In en, this message translates to:
  /// **'Quick entry'**
  String get onboardingQuickEntry;

  /// No description provided for @onboardingInstantPayment.
  ///
  /// In en, this message translates to:
  /// **'Instant payment'**
  String get onboardingInstantPayment;

  /// No description provided for @onboardingSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved instantly'**
  String get onboardingSaved;

  /// No description provided for @onboardingSeconds.
  ///
  /// In en, this message translates to:
  /// **'In just 3 seconds'**
  String get onboardingSeconds;

  /// No description provided for @onboardingSampleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer: Emad Taha'**
  String get onboardingSampleCustomer;

  /// No description provided for @onboardingSampleAmount.
  ///
  /// In en, this message translates to:
  /// **'EGP 250'**
  String get onboardingSampleAmount;

  /// No description provided for @onboardingStorageError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your preference. Please try again.'**
  String get onboardingStorageError;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceTitle;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsAppearanceCaption.
  ///
  /// In en, this message translates to:
  /// **'The light paper theme is designed to suit traditional ledgers in sunlight.'**
  String get settingsAppearanceCaption;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get settingsLanguageArabic;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageChange.
  ///
  /// In en, this message translates to:
  /// **'Tap to change the language'**
  String get settingsLanguageChange;

  /// No description provided for @settingsLanguagePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get settingsLanguagePickerTitle;

  /// No description provided for @settingsLanguagePickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the interface display language'**
  String get settingsLanguagePickerSubtitle;

  /// No description provided for @settingsLanguageArabicDescription.
  ///
  /// In en, this message translates to:
  /// **'Complete Arabic interface'**
  String get settingsLanguageArabicDescription;

  /// No description provided for @settingsLanguageEnglishDescription.
  ///
  /// In en, this message translates to:
  /// **'English user interface'**
  String get settingsLanguageEnglishDescription;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'You can always change the language later from Settings.'**
  String get settingsLanguageHint;

  /// No description provided for @settingsLanguageBadgeArabic.
  ///
  /// In en, this message translates to:
  /// **'ع'**
  String get settingsLanguageBadgeArabic;

  /// No description provided for @settingsLanguageBadgeEnglish.
  ///
  /// In en, this message translates to:
  /// **'En'**
  String get settingsLanguageBadgeEnglish;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutTitle;

  /// No description provided for @settingsVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get settingsVersionLabel;

  /// No description provided for @settingsVersionStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get settingsVersionStable;

  /// No description provided for @settingsStorageError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your preference. Please try again.'**
  String get settingsStorageError;

  /// No description provided for @customersTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersTitle;

  /// No description provided for @customersHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get customersHome;

  /// No description provided for @customerNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New customer'**
  String get customerNewTitle;

  /// No description provided for @customerEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get customerEditTitle;

  /// No description provided for @customerDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer details'**
  String get customerDetailsTitle;

  /// No description provided for @customerFormHeading.
  ///
  /// In en, this message translates to:
  /// **'A new page in your ledger'**
  String get customerFormHeading;

  /// No description provided for @customerFormDescription.
  ///
  /// In en, this message translates to:
  /// **'Record customer details to keep their account organized.'**
  String get customerFormDescription;

  /// No description provided for @customerImport.
  ///
  /// In en, this message translates to:
  /// **'Import from contacts'**
  String get customerImport;

  /// No description provided for @customerImportDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a contact to save time'**
  String get customerImportDescription;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get customerName;

  /// No description provided for @customerNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the customer name'**
  String get customerNameHint;

  /// No description provided for @customerPhone.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get customerPhone;

  /// No description provided for @customerPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the mobile number'**
  String get customerPhoneHint;

  /// No description provided for @customerNotes.
  ///
  /// In en, this message translates to:
  /// **'Note or address'**
  String get customerNotes;

  /// No description provided for @customerNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note or address'**
  String get customerNotesHint;

  /// No description provided for @customerSave.
  ///
  /// In en, this message translates to:
  /// **'Save customer'**
  String get customerSave;

  /// No description provided for @customerBalance.
  ///
  /// In en, this message translates to:
  /// **'Current outstanding balance'**
  String get customerBalance;

  /// No description provided for @customerCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get customerCall;

  /// No description provided for @customerCallError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the phone app.'**
  String get customerCallError;

  /// No description provided for @customerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get customerEdit;

  /// No description provided for @customerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Customer not found'**
  String get customerNotFound;

  /// No description provided for @customersSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone...'**
  String get customersSearch;

  /// No description provided for @customersAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get customersAll;

  /// No description provided for @customersOwes.
  ///
  /// In en, this message translates to:
  /// **'Owes'**
  String get customersOwes;

  /// No description provided for @customersSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get customersSettled;

  /// No description provided for @customersAdd.
  ///
  /// In en, this message translates to:
  /// **'New customer'**
  String get customersAdd;

  /// No description provided for @customersAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add first customer'**
  String get customersAddFirst;

  /// No description provided for @customersEmptyBadge.
  ///
  /// In en, this message translates to:
  /// **'Your notebook is still new'**
  String get customersEmptyBadge;

  /// No description provided for @customersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get customersEmptyTitle;

  /// No description provided for @customersEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add your first customer and start recording credit and payments easily.'**
  String get customersEmptyMessage;

  /// No description provided for @customersNoResults.
  ///
  /// In en, this message translates to:
  /// **'No customers match your search.'**
  String get customersNoResults;

  /// No description provided for @customersTotalDebt.
  ///
  /// In en, this message translates to:
  /// **'Total debt'**
  String get customersTotalDebt;

  /// No description provided for @customersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} customers • {owing} owe a balance'**
  String customersCount(int count, int owing);

  /// No description provided for @customersSample1.
  ///
  /// In en, this message translates to:
  /// **'Mohamed Abdel Fattah'**
  String get customersSample1;

  /// No description provided for @customersSample2.
  ///
  /// In en, this message translates to:
  /// **'Ahmed El Shenawy'**
  String get customersSample2;

  /// No description provided for @customersSample3.
  ///
  /// In en, this message translates to:
  /// **'Sameh the grocer'**
  String get customersSample3;

  /// No description provided for @customersSample4.
  ///
  /// In en, this message translates to:
  /// **'Hussein the carpenter'**
  String get customersSample4;

  /// No description provided for @customersSample5.
  ///
  /// In en, this message translates to:
  /// **'Umm Karim'**
  String get customersSample5;

  /// No description provided for @customersSample6.
  ///
  /// In en, this message translates to:
  /// **'Ibrahim the blacksmith'**
  String get customersSample6;

  /// No description provided for @customersSample7.
  ///
  /// In en, this message translates to:
  /// **'Ali the plumber'**
  String get customersSample7;

  /// No description provided for @customersComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming in the next task'**
  String get customersComingSoon;

  /// No description provided for @customerErrorDatabase.
  ///
  /// In en, this message translates to:
  /// **'Could not access customer data. Please try again.'**
  String get customerErrorDatabase;

  /// No description provided for @customerErrorStorage.
  ///
  /// In en, this message translates to:
  /// **'Could not access storage. Please try again.'**
  String get customerErrorStorage;

  /// No description provided for @customerErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please try again.'**
  String get customerErrorNetwork;

  /// No description provided for @customerErrorAuth.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please try again.'**
  String get customerErrorAuth;

  /// No description provided for @customerErrorPicker.
  ///
  /// In en, this message translates to:
  /// **'Could not open contacts. You can enter details manually.'**
  String get customerErrorPicker;

  /// No description provided for @customerErrorValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a name and a valid Egyptian mobile number.'**
  String get customerErrorValidation;

  /// No description provided for @customerErrorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get customerErrorUnexpected;

  /// No description provided for @customersSort.
  ///
  /// In en, this message translates to:
  /// **'Sort customers'**
  String get customersSort;

  /// No description provided for @customersSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get customersSortName;

  /// No description provided for @customersSortBalance.
  ///
  /// In en, this message translates to:
  /// **'Highest balance'**
  String get customersSortBalance;

  /// No description provided for @customersSortRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get customersSortRecent;

  /// No description provided for @customerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete customer'**
  String get customerDelete;

  /// No description provided for @customerDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete this customer? Their ledger history will be preserved.'**
  String get customerDeleteMessage;

  /// No description provided for @customerDeleteBalanceMessage.
  ///
  /// In en, this message translates to:
  /// **'This customer has an outstanding balance of {balance}. Delete them? Their ledger history will be preserved.'**
  String customerDeleteBalanceMessage(String balance);

  /// No description provided for @transactionNew.
  ///
  /// In en, this message translates to:
  /// **'New transaction'**
  String get transactionNew;

  /// No description provided for @transactionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get transactionEdit;

  /// No description provided for @transactionCredit.
  ///
  /// In en, this message translates to:
  /// **'Owes (credit)'**
  String get transactionCredit;

  /// No description provided for @transactionPayment.
  ///
  /// In en, this message translates to:
  /// **'Paid (payment)'**
  String get transactionPayment;

  /// No description provided for @transactionCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get transactionCustomer;

  /// No description provided for @transactionChooseCustomer.
  ///
  /// In en, this message translates to:
  /// **'Choose customer'**
  String get transactionChooseCustomer;

  /// No description provided for @transactionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get transactionChange;

  /// No description provided for @transactionAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount to record'**
  String get transactionAmount;

  /// No description provided for @transactionQuickAmounts.
  ///
  /// In en, this message translates to:
  /// **'Quick amounts'**
  String get transactionQuickAmounts;

  /// No description provided for @transactionDate.
  ///
  /// In en, this message translates to:
  /// **'Transaction date'**
  String get transactionDate;

  /// No description provided for @transactionNote.
  ///
  /// In en, this message translates to:
  /// **'Note or item description (optional)'**
  String get transactionNote;

  /// No description provided for @transactionSave.
  ///
  /// In en, this message translates to:
  /// **'Save transaction'**
  String get transactionSave;

  /// No description provided for @transactionMockNotice.
  ///
  /// In en, this message translates to:
  /// **'Preview only — transactions are not saved.'**
  String get transactionMockNotice;

  /// No description provided for @transactionMockHistory.
  ///
  /// In en, this message translates to:
  /// **'Sample history — not this customer\'s transactions'**
  String get transactionMockHistory;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get transactionHistory;

  /// No description provided for @transactionSampleCredit.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get transactionSampleCredit;

  /// No description provided for @transactionSamplePayment.
  ///
  /// In en, this message translates to:
  /// **'Cash payment'**
  String get transactionSamplePayment;

  /// No description provided for @transactionBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get transactionBalance;

  /// No description provided for @transactionBackspace.
  ///
  /// In en, this message translates to:
  /// **'Delete digit'**
  String get transactionBackspace;

  /// No description provided for @transactionSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save the transaction. Check the customer and amount, then try again.'**
  String get transactionSaveError;

  /// No description provided for @transactionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Transaction not found.'**
  String get transactionNotFound;

  /// No description provided for @transactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} transactions'**
  String transactionCount(int count);

  /// No description provided for @transactionHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get transactionHistoryEmpty;

  /// No description provided for @transactionHistoryError.
  ///
  /// In en, this message translates to:
  /// **'Could not load or change transactions. Please try again.'**
  String get transactionHistoryError;

  /// No description provided for @transactionBalanceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Balance too large to display'**
  String get transactionBalanceUnavailable;

  /// No description provided for @transactionDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete this transaction? Its previous values will be retained in the audit history.'**
  String get transactionDeleteMessage;

  /// No description provided for @transactionHistoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sample transactions'**
  String transactionHistoryCount(int count);

  /// No description provided for @transactionCreditBadge.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get transactionCreditBadge;

  /// No description provided for @transactionPaymentBadge.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get transactionPaymentBadge;

  /// No description provided for @transactionEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get transactionEditAction;

  /// No description provided for @transactionDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get transactionDeleteAction;

  /// No description provided for @transactionSampleCreditNote.
  ///
  /// In en, this message translates to:
  /// **'Grocery purchase'**
  String get transactionSampleCreditNote;

  /// No description provided for @transactionSamplePaymentNote.
  ///
  /// In en, this message translates to:
  /// **'Cash received'**
  String get transactionSamplePaymentNote;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Account ledger'**
  String get dashboardTitle;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get dashboardSubtitle;

  /// No description provided for @dashboardGreetingCaption.
  ///
  /// In en, this message translates to:
  /// **'Good morning, boss,'**
  String get dashboardGreetingCaption;

  /// No description provided for @dashboardWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to your shop'**
  String get dashboardWelcome;

  /// No description provided for @dashboardTotalOwed.
  ///
  /// In en, this message translates to:
  /// **'Total owed by customers'**
  String get dashboardTotalOwed;

  /// No description provided for @dashboardDebtorCount.
  ///
  /// In en, this message translates to:
  /// **'{count} customers with an outstanding balance'**
  String dashboardDebtorCount(int count);

  /// No description provided for @dashboardTodayCollections.
  ///
  /// In en, this message translates to:
  /// **'Today\'s collections'**
  String get dashboardTodayCollections;

  /// No description provided for @dashboardRegisterTransaction.
  ///
  /// In en, this message translates to:
  /// **'Record transaction'**
  String get dashboardRegisterTransaction;

  /// No description provided for @dashboardNewCustomer.
  ///
  /// In en, this message translates to:
  /// **'New customer'**
  String get dashboardNewCustomer;

  /// No description provided for @dashboardTopDebtors.
  ///
  /// In en, this message translates to:
  /// **'Top debtors'**
  String get dashboardTopDebtors;

  /// No description provided for @dashboardViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get dashboardViewAll;

  /// No description provided for @dashboardRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get dashboardRecentActivity;

  /// No description provided for @dashboardUpdatedLive.
  ///
  /// In en, this message translates to:
  /// **'Updated live'**
  String get dashboardUpdatedLive;

  /// No description provided for @dashboardActivityDate.
  ///
  /// In en, this message translates to:
  /// **'{day}, {time}'**
  String dashboardActivityDate(String day, String time);

  /// No description provided for @dashboardTipTitle.
  ///
  /// In en, this message translates to:
  /// **'Your ledger is organized and protected'**
  String get dashboardTipTitle;

  /// No description provided for @dashboardTipMessage.
  ///
  /// In en, this message translates to:
  /// **'Record every penny as it happens so your accounts and your customers\' rights are never lost.'**
  String get dashboardTipMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
