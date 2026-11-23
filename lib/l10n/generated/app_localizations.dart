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

  /// No description provided for @securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityTitle;

  /// No description provided for @securityBrandCaption.
  ///
  /// In en, this message translates to:
  /// **'Daftari • Ledger protection'**
  String get securityBrandCaption;

  /// No description provided for @securityPinHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter 4 digits to continue'**
  String get securityPinHelper;

  /// No description provided for @securityClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get securityClearAll;

  /// No description provided for @securityPreview.
  ///
  /// In en, this message translates to:
  /// **'UI preview only — your app is not locked. Demo PIN: 1234.'**
  String get securityPreview;

  /// No description provided for @securityPin.
  ///
  /// In en, this message translates to:
  /// **'App PIN'**
  String get securityPin;

  /// No description provided for @securityPinDescription.
  ///
  /// In en, this message translates to:
  /// **'Protect your ledger with a 4-digit PIN'**
  String get securityPinDescription;

  /// No description provided for @securityChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get securityChangePin;

  /// No description provided for @securityBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock'**
  String get securityBiometrics;

  /// No description provided for @securityBiometricsDescription.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint or face recognition'**
  String get securityBiometricsDescription;

  /// No description provided for @securityAutoLock.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get securityAutoLock;

  /// No description provided for @securityImmediate.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get securityImmediate;

  /// No description provided for @securityOneMinute.
  ///
  /// In en, this message translates to:
  /// **'After 1 minute'**
  String get securityOneMinute;

  /// No description provided for @securityFiveMinutes.
  ///
  /// In en, this message translates to:
  /// **'After 5 minutes'**
  String get securityFiveMinutes;

  /// No description provided for @securityUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get securityUnlockTitle;

  /// No description provided for @securityUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your customers and ledger private'**
  String get securityUnlockSubtitle;

  /// No description provided for @securitySetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your PIN'**
  String get securitySetupTitle;

  /// No description provided for @securitySetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a 4-digit PIN for your ledger'**
  String get securitySetupSubtitle;

  /// No description provided for @securityConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your PIN'**
  String get securityConfirmTitle;

  /// No description provided for @securityConfirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the same PIN again'**
  String get securityConfirmSubtitle;

  /// No description provided for @securityChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change your PIN'**
  String get securityChangeTitle;

  /// No description provided for @securityDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off PIN'**
  String get securityDisableTitle;

  /// No description provided for @securityCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your current PIN to continue'**
  String get securityCurrentPin;

  /// No description provided for @securityResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your PIN'**
  String get securityResetTitle;

  /// No description provided for @securityPinError.
  ///
  /// In en, this message translates to:
  /// **'PIN did not match. Please try again.'**
  String get securityPinError;

  /// No description provided for @securityForgotPin.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get securityForgotPin;

  /// No description provided for @securityBiometricAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get securityBiometricAction;

  /// No description provided for @securityRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover access'**
  String get securityRecoveryTitle;

  /// No description provided for @securityRecoveryGuidance.
  ///
  /// In en, this message translates to:
  /// **'Recovery requires a device screen lock. Without one, reinstalling the app is the only way to reset access and may permanently remove your local ledger. No data has been changed.'**
  String get securityRecoveryGuidance;

  /// No description provided for @securityRecoveryPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview device-credential recovery? No OS authentication will run and no real PIN will be reset.'**
  String get securityRecoveryPreview;

  /// No description provided for @securityBiometricPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview biometric unlock? No OS authentication will run.'**
  String get securityBiometricPreview;

  /// No description provided for @securityComplete.
  ///
  /// In en, this message translates to:
  /// **'PIN updated'**
  String get securityComplete;

  /// No description provided for @securityCompleteDescription.
  ///
  /// In en, this message translates to:
  /// **'Your security settings have been saved.'**
  String get securityCompleteDescription;

  /// No description provided for @securityStorageError.
  ///
  /// In en, this message translates to:
  /// **'Security data could not be read or saved safely. Access is locked. Restart the app and try again. Your ledger has not been deleted.'**
  String get securityStorageError;

  /// No description provided for @securityAuthUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Authentication was cancelled or unavailable. Please try again or use your app PIN.'**
  String get securityAuthUnavailable;

  /// No description provided for @securityCooldown.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds} seconds.'**
  String securityCooldown(int seconds);

  /// No description provided for @securityDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get securityDone;

  /// No description provided for @securityDeleteDigit.
  ///
  /// In en, this message translates to:
  /// **'Delete last digit'**
  String get securityDeleteDigit;

  /// No description provided for @securityPinProgress.
  ///
  /// In en, this message translates to:
  /// **'{count} of 4 PIN digits entered'**
  String securityPinProgress(int count);

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

  /// No description provided for @statementTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer statement'**
  String get statementTitle;

  /// No description provided for @statementLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the statement. Please try again.'**
  String get statementLoadError;

  /// No description provided for @statementShareError.
  ///
  /// In en, this message translates to:
  /// **'Could not share the statement. Please try again.'**
  String get statementShareError;

  /// No description provided for @statementCopyError.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the statement. Please try again.'**
  String get statementCopyError;

  /// No description provided for @statementCopied.
  ///
  /// In en, this message translates to:
  /// **'Statement copied'**
  String get statementCopied;

  /// No description provided for @statementEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions in this period.'**
  String get statementEmpty;

  /// No description provided for @statementSettledHint.
  ///
  /// In en, this message translates to:
  /// **'No outstanding balance'**
  String get statementSettledHint;

  /// No description provided for @statementCreditBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'Credit in the customer\'s favor'**
  String get statementCreditBalanceHint;

  /// No description provided for @statementPeriodCredit.
  ///
  /// In en, this message translates to:
  /// **'Period credit total: {amount}'**
  String statementPeriodCredit(String amount);

  /// No description provided for @statementPeriodPayment.
  ///
  /// In en, this message translates to:
  /// **'Period payment total: {amount}'**
  String statementPeriodPayment(String amount);

  /// No description provided for @statementPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview before sending'**
  String get statementPreviewTitle;

  /// No description provided for @statementPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review the entries before sharing with your customer.'**
  String get statementPreviewSubtitle;

  /// No description provided for @statementMockNotice.
  ///
  /// In en, this message translates to:
  /// **'Sample statement — not this customer\'s data. Filters, sharing, and copying are not available in this preview.'**
  String get statementMockNotice;

  /// No description provided for @statementGeneratedAt.
  ///
  /// In en, this message translates to:
  /// **'Generated: {date} • {time}'**
  String statementGeneratedAt(String date, String time);

  /// No description provided for @statementBalance.
  ///
  /// In en, this message translates to:
  /// **'Total outstanding balance'**
  String get statementBalance;

  /// No description provided for @statementBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'Please pay the balance or make a payment'**
  String get statementBalanceHint;

  /// No description provided for @statementRangeAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get statementRangeAll;

  /// No description provided for @statementRangeLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get statementRangeLast30Days;

  /// No description provided for @statementRangeThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get statementRangeThisMonth;

  /// No description provided for @statementRangeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get statementRangeCustom;

  /// No description provided for @statementEntriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Account activity'**
  String get statementEntriesTitle;

  /// No description provided for @statementFooter.
  ///
  /// In en, this message translates to:
  /// **'Thank you for shopping with us. We\'re always happy to help.'**
  String get statementFooter;

  /// No description provided for @statementWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Send via WhatsApp'**
  String get statementWhatsApp;

  /// No description provided for @statementCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get statementCopy;

  /// No description provided for @statementShareHint.
  ///
  /// In en, this message translates to:
  /// **'Shares statement images. Choose WhatsApp or another app, then send.'**
  String get statementShareHint;

  /// No description provided for @statementImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Account statement'**
  String get statementImageTitle;

  /// No description provided for @statementImageShare.
  ///
  /// In en, this message translates to:
  /// **'Share statement image'**
  String get statementImageShare;

  /// No description provided for @statementImageFooter.
  ///
  /// In en, this message translates to:
  /// **'Statement generated by Daftari'**
  String get statementImageFooter;

  /// No description provided for @statementImagePage.
  ///
  /// In en, this message translates to:
  /// **'{page} / {total}'**
  String statementImagePage(int page, int total);

  /// No description provided for @statementShareWithCustomer.
  ///
  /// In en, this message translates to:
  /// **'Share statement with customer'**
  String get statementShareWithCustomer;

  /// No description provided for @statementSampleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Mahmoud El Shenawy'**
  String get statementSampleCustomer;

  /// No description provided for @statementSampleCredit1.
  ///
  /// In en, this message translates to:
  /// **'Sugar and a carton of oil'**
  String get statementSampleCredit1;

  /// No description provided for @statementSampleCredit2.
  ///
  /// In en, this message translates to:
  /// **'2 kg of cheese'**
  String get statementSampleCredit2;

  /// No description provided for @statementSampleCredit3.
  ///
  /// In en, this message translates to:
  /// **'Household groceries'**
  String get statementSampleCredit3;

  /// No description provided for @statementSamplePayment1.
  ///
  /// In en, this message translates to:
  /// **'Cash payment'**
  String get statementSamplePayment1;

  /// No description provided for @statementSamplePayment2.
  ///
  /// In en, this message translates to:
  /// **'Cash wallet transfer'**
  String get statementSamplePayment2;

  /// No description provided for @authLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authLoginTitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authRegisterTitle;

  /// No description provided for @authForgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authForgotTitle;

  /// No description provided for @authVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get authVerifyTitle;

  /// No description provided for @authUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authUpdateTitle;

  /// No description provided for @authLoginHeading.
  ///
  /// In en, this message translates to:
  /// **'Protect your data from loss'**
  String get authLoginHeading;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Link your local ledger to your account so customer balances and debts are never lost if your phone changes or is lost.'**
  String get authLoginSubtitle;

  /// No description provided for @authRegisterHeading.
  ///
  /// In en, this message translates to:
  /// **'Protect your data from loss'**
  String get authRegisterHeading;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account to link your local ledger for optional secure backup and restore, even if your phone is lost.'**
  String get authRegisterSubtitle;

  /// No description provided for @authForgotHeading.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get authForgotHeading;

  /// No description provided for @authForgotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we will send you a link to reset your password.'**
  String get authForgotSubtitle;

  /// No description provided for @authVerifyHeading.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get authVerifyHeading;

  /// No description provided for @authVerifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to {email}. Open it to activate your account.'**
  String authVerifySubtitle(String email);

  /// No description provided for @authVerifyGenericSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the verification link in your email to activate your account.'**
  String get authVerifyGenericSubtitle;

  /// No description provided for @authUpdateHeading.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get authUpdateHeading;

  /// No description provided for @authUpdateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password for your account.'**
  String get authUpdateSubtitle;

  /// No description provided for @authSecureBadge.
  ///
  /// In en, this message translates to:
  /// **'Secure encryption'**
  String get authSecureBadge;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authEmailHint.
  ///
  /// In en, this message translates to:
  /// **'example@gmail.com'**
  String get authEmailHint;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordHint;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccount;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create a new account'**
  String get authCreateAccount;

  /// No description provided for @authShopName.
  ///
  /// In en, this message translates to:
  /// **'Shop / merchant name'**
  String get authShopName;

  /// No description provided for @authShopNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Al-Amana Grocery or Abu Omar'**
  String get authShopNameHint;

  /// No description provided for @authShopNameViewerHint.
  ///
  /// In en, this message translates to:
  /// **'Shown on customer statements'**
  String get authShopNameViewerHint;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authRegisterAction.
  ///
  /// In en, this message translates to:
  /// **'Create account and save ledger'**
  String get authRegisterAction;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHaveAccount;

  /// No description provided for @authSignInLink.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInLink;

  /// No description provided for @authRegisterConsent.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to the terms of use and data protection policy. Your ledger data remains yours alone.'**
  String get authRegisterConsent;

  /// No description provided for @authOfflineNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Your ledger always works offline'**
  String get authOfflineNoteTitle;

  /// No description provided for @authOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'Signing in enables optional secure backup to help protect your ledger if your phone is stolen or damaged.'**
  String get authOfflineNote;

  /// No description provided for @authContinueOffline.
  ///
  /// In en, this message translates to:
  /// **'Continue with local ledger (later)'**
  String get authContinueOffline;

  /// No description provided for @authContinueOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'You can keep using the ledger locally and back up later.'**
  String get authContinueOfflineHint;

  /// No description provided for @authLoginMockNotice.
  ///
  /// In en, this message translates to:
  /// **'Preview only — sign-in isn\'t available yet.'**
  String get authLoginMockNotice;

  /// No description provided for @authRegisterMockNotice.
  ///
  /// In en, this message translates to:
  /// **'Preview only — account creation isn\'t available yet.'**
  String get authRegisterMockNotice;

  /// No description provided for @authSendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authSendResetLink;

  /// No description provided for @authResetSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authResetSentTitle;

  /// No description provided for @authResetSentMessage.
  ///
  /// In en, this message translates to:
  /// **'We sent a password reset link to {email}.'**
  String authResetSentMessage(String email);

  /// No description provided for @authBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authBackToLogin;

  /// No description provided for @authForgotMockNotice.
  ///
  /// In en, this message translates to:
  /// **'Preview only — no email will be sent.'**
  String get authForgotMockNotice;

  /// No description provided for @authResendVerification.
  ///
  /// In en, this message translates to:
  /// **'Resend verification link'**
  String get authResendVerification;

  /// No description provided for @authResendSent.
  ///
  /// In en, this message translates to:
  /// **'Verification link sent again.'**
  String get authResendSent;

  /// No description provided for @authVerifiedAction.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified my email'**
  String get authVerifiedAction;

  /// No description provided for @authVerifyMockNotice.
  ///
  /// In en, this message translates to:
  /// **'Preview only — email verification isn\'t available yet.'**
  String get authVerifyMockNotice;

  /// No description provided for @authNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPassword;

  /// No description provided for @authUpdatePasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get authUpdatePasswordAction;

  /// No description provided for @authUpdateMockNotice.
  ///
  /// In en, this message translates to:
  /// **'Preview only — password update isn\'t available yet.'**
  String get authUpdateMockNotice;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordMismatch;

  /// No description provided for @authShopNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a shop name'**
  String get authShopNameRequired;

  /// No description provided for @authLinkDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Link this ledger to your account?'**
  String get authLinkDialogTitle;

  /// No description provided for @authLinkDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'This device\'s local ledger will be linked to your account. Nothing is uploaded yet, and your data stays on your device. Once linked, this device\'s ledger can only be used with this account.'**
  String get authLinkDialogMessage;

  /// No description provided for @authLinkDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Link ledger'**
  String get authLinkDialogConfirm;

  /// No description provided for @authAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get authAccountTitle;

  /// No description provided for @authAccountSignedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get authAccountSignedOutTitle;

  /// No description provided for @authAccountSignedOutDescription.
  ///
  /// In en, this message translates to:
  /// **'Link your ledger to an account so your data is never lost.'**
  String get authAccountSignedOutDescription;

  /// No description provided for @authAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authAccountSignIn;

  /// No description provided for @authAccountCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authAccountCreate;

  /// No description provided for @authAccountLinkedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ledger linked'**
  String get authAccountLinkedTitle;

  /// No description provided for @authAccountLinkedTo.
  ///
  /// In en, this message translates to:
  /// **'Linked to {email}'**
  String authAccountLinkedTo(String email);

  /// No description provided for @authAccountVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get authAccountVerified;

  /// No description provided for @authAccountEmailUnverified.
  ///
  /// In en, this message translates to:
  /// **'Email not verified'**
  String get authAccountEmailUnverified;

  /// No description provided for @authAccountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authAccountSignOut;

  /// No description provided for @authAccountLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Your data is stored on this device'**
  String get authAccountLocalOnly;

  /// No description provided for @authAccountMockNotice.
  ///
  /// In en, this message translates to:
  /// **'Preview only — account is not connected yet.'**
  String get authAccountMockNotice;

  /// No description provided for @authAccountSignOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign out? Your local ledger data will not be deleted.'**
  String get authAccountSignOutMessage;

  /// No description provided for @authErrorAccountMismatch.
  ///
  /// In en, this message translates to:
  /// **'This device\'s ledger is linked to another account. Sign in with the original account to continue.'**
  String get authErrorAccountMismatch;

  /// No description provided for @authErrorAuth.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Check your email and password and try again.'**
  String get authErrorAuth;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Check your internet connection and try again.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorUnconfigured.
  ///
  /// In en, this message translates to:
  /// **'Account sign-in is not configured in this build. Your ledger continues to work locally.'**
  String get authErrorUnconfigured;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorGeneric;

  /// No description provided for @authPasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully.'**
  String get authPasswordUpdated;

  /// No description provided for @authEmailNotVerifiedYet.
  ///
  /// In en, this message translates to:
  /// **'Your email is not verified yet. Open the link in your inbox and try again.'**
  String get authEmailNotVerifiedYet;

  /// No description provided for @authSignedOutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Signed out. Your local ledger data is safe on this device.'**
  String get authSignedOutSuccess;

  /// No description provided for @authLinkedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Ledger linked to your account.'**
  String get authLinkedSuccess;

  /// No description provided for @backupSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup'**
  String get backupSectionTitle;

  /// No description provided for @backupSyncStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync status'**
  String get backupSyncStatusTitle;

  /// No description provided for @backupStatusNeverBackedUp.
  ///
  /// In en, this message translates to:
  /// **'Not backed up yet'**
  String get backupStatusNeverBackedUp;

  /// No description provided for @backupStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Changes pending'**
  String get backupStatusPending;

  /// No description provided for @backupStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Backing up…'**
  String get backupStatusRunning;

  /// No description provided for @backupStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed'**
  String get backupStatusFailed;

  /// No description provided for @backupStatusUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Connected & secure'**
  String get backupStatusUpToDate;

  /// No description provided for @backupLastConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {day}, {time}'**
  String backupLastConfirmed(String day, String time);

  /// No description provided for @backupNeverConfirmed.
  ///
  /// In en, this message translates to:
  /// **'No backup yet'**
  String get backupNeverConfirmed;

  /// No description provided for @backupPendingChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No pending changes} =1{1 change pending} other{{count} changes pending}}'**
  String backupPendingChanges(int count);

  /// No description provided for @backupFailedHint.
  ///
  /// In en, this message translates to:
  /// **'The last attempt didn\'t finish. Your previous backup is safe.'**
  String get backupFailedHint;

  /// No description provided for @backupNowAction.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupNowAction;

  /// No description provided for @backupNowTitle.
  ///
  /// In en, this message translates to:
  /// **'Save an instant cloud copy'**
  String get backupNowTitle;

  /// No description provided for @backupNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secure all debts and payments now'**
  String get backupNowSubtitle;

  /// No description provided for @backupManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage backup'**
  String get backupManageTitle;

  /// No description provided for @backupManageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backup schedule and status'**
  String get backupManageSubtitle;

  /// No description provided for @backupScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup settings'**
  String get backupScreenTitle;

  /// No description provided for @backupActiveAccount.
  ///
  /// In en, this message translates to:
  /// **'Active account'**
  String get backupActiveAccount;

  /// No description provided for @backupScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup schedule'**
  String get backupScheduleTitle;

  /// No description provided for @backupScheduleDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get backupScheduleDaily;

  /// No description provided for @backupScheduleWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get backupScheduleWeekly;

  /// No description provided for @backupScheduleMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get backupScheduleMonthly;

  /// No description provided for @backupScheduleCaption.
  ///
  /// In en, this message translates to:
  /// **'Choose how often to back up automatically when Android allows.'**
  String get backupScheduleCaption;

  /// No description provided for @backupMockNotice.
  ///
  /// In en, this message translates to:
  /// **'Preview only — backup isn\'t available yet.'**
  String get backupMockNotice;
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
