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
}
