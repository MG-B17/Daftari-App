// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get securityTitle => 'Security';

  @override
  String get securityBrandCaption => 'Daftari • Ledger protection';

  @override
  String get securityPinHelper => 'Enter 4 digits to continue';

  @override
  String get securityClearAll => 'Clear all';

  @override
  String get securityPreview =>
      'UI preview only — your app is not locked. Demo PIN: 1234.';

  @override
  String get securityPin => 'App PIN';

  @override
  String get securityPinDescription => 'Protect your ledger with a 4-digit PIN';

  @override
  String get securityChangePin => 'Change PIN';

  @override
  String get securityBiometrics => 'Biometric unlock';

  @override
  String get securityBiometricsDescription =>
      'Use fingerprint or face recognition';

  @override
  String get securityAutoLock => 'Auto-lock';

  @override
  String get securityImmediate => 'Immediately';

  @override
  String get securityOneMinute => 'After 1 minute';

  @override
  String get securityFiveMinutes => 'After 5 minutes';

  @override
  String get securityUnlockTitle => 'Enter your PIN';

  @override
  String get securityUnlockSubtitle => 'Keep your customers and ledger private';

  @override
  String get securitySetupTitle => 'Create your PIN';

  @override
  String get securitySetupSubtitle => 'Choose a 4-digit PIN for your ledger';

  @override
  String get securityConfirmTitle => 'Confirm your PIN';

  @override
  String get securityConfirmSubtitle => 'Enter the same PIN again';

  @override
  String get securityChangeTitle => 'Change your PIN';

  @override
  String get securityDisableTitle => 'Turn off PIN';

  @override
  String get securityCurrentPin => 'Enter your current PIN to continue';

  @override
  String get securityResetTitle => 'Reset your PIN';

  @override
  String get securityPinError => 'PIN did not match. Please try again.';

  @override
  String get securityForgotPin => 'Forgot PIN?';

  @override
  String get securityBiometricAction => 'Unlock with biometrics';

  @override
  String get securityRecoveryTitle => 'Recover access';

  @override
  String get securityRecoveryGuidance =>
      'Recovery requires a device screen lock. Without one, reinstalling the app is the only way to reset access and may permanently remove your local ledger. No data has been changed.';

  @override
  String get securityRecoveryPreview =>
      'Preview device-credential recovery? No OS authentication will run and no real PIN will be reset.';

  @override
  String get securityBiometricPreview =>
      'Preview biometric unlock? No OS authentication will run.';

  @override
  String get securityComplete => 'PIN updated';

  @override
  String get securityCompleteDescription =>
      'Your security settings have been saved.';

  @override
  String get securityStorageError =>
      'Security data could not be read or saved safely. Access is locked. Restart the app and try again. Your ledger has not been deleted.';

  @override
  String get securityAuthUnavailable =>
      'Authentication was cancelled or unavailable. Please try again or use your app PIN.';

  @override
  String securityCooldown(int seconds) {
    return 'Too many attempts. Try again in $seconds seconds.';
  }

  @override
  String get securityDone => 'Done';

  @override
  String get securityDeleteDigit => 'Delete last digit';

  @override
  String securityPinProgress(int count) {
    return '$count of 4 PIN digits entered';
  }

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

  @override
  String get customerErrorDatabase =>
      'Could not access customer data. Please try again.';

  @override
  String get customerErrorStorage =>
      'Could not access storage. Please try again.';

  @override
  String get customerErrorNetwork => 'Network error. Please try again.';

  @override
  String get customerErrorAuth => 'Authentication failed. Please try again.';

  @override
  String get customerErrorPicker =>
      'Could not open contacts. You can enter details manually.';

  @override
  String get customerErrorValidation =>
      'Enter a name and a valid Egyptian mobile number.';

  @override
  String get customerErrorUnexpected =>
      'Something went wrong. Please try again.';

  @override
  String get customersSort => 'Sort customers';

  @override
  String get customersSortName => 'Name';

  @override
  String get customersSortBalance => 'Highest balance';

  @override
  String get customersSortRecent => 'Recently added';

  @override
  String get customerDelete => 'Delete customer';

  @override
  String get customerDeleteMessage =>
      'Delete this customer? Their ledger history will be preserved.';

  @override
  String customerDeleteBalanceMessage(String balance) {
    return 'This customer has an outstanding balance of $balance. Delete them? Their ledger history will be preserved.';
  }

  @override
  String get transactionNew => 'New transaction';

  @override
  String get transactionEdit => 'Edit transaction';

  @override
  String get transactionCredit => 'Owes (credit)';

  @override
  String get transactionPayment => 'Paid (payment)';

  @override
  String get transactionCustomer => 'Customer';

  @override
  String get transactionChooseCustomer => 'Choose customer';

  @override
  String get transactionChange => 'Change';

  @override
  String get transactionAmount => 'Amount to record';

  @override
  String get transactionQuickAmounts => 'Quick amounts';

  @override
  String get transactionDate => 'Transaction date';

  @override
  String get transactionNote => 'Note or item description (optional)';

  @override
  String get transactionSave => 'Save transaction';

  @override
  String get transactionMockNotice =>
      'Preview only — transactions are not saved.';

  @override
  String get transactionMockHistory =>
      'Sample history — not this customer\'s transactions';

  @override
  String get transactionHistory => 'Transaction history';

  @override
  String get transactionSampleCredit => 'Groceries';

  @override
  String get transactionSamplePayment => 'Cash payment';

  @override
  String get transactionBalance => 'Balance';

  @override
  String get transactionBackspace => 'Delete digit';

  @override
  String get transactionSaveError =>
      'Could not save the transaction. Check the customer and amount, then try again.';

  @override
  String get transactionNotFound => 'Transaction not found.';

  @override
  String transactionCount(int count) {
    return '$count transactions';
  }

  @override
  String get transactionHistoryEmpty => 'No transactions yet.';

  @override
  String get transactionHistoryError =>
      'Could not load or change transactions. Please try again.';

  @override
  String get transactionBalanceUnavailable => 'Balance too large to display';

  @override
  String get transactionDeleteMessage =>
      'Delete this transaction? Its previous values will be retained in the audit history.';

  @override
  String transactionHistoryCount(int count) {
    return '$count sample transactions';
  }

  @override
  String get transactionCreditBadge => 'Credit';

  @override
  String get transactionPaymentBadge => 'Paid';

  @override
  String get transactionEditAction => 'Edit';

  @override
  String get transactionDeleteAction => 'Delete';

  @override
  String get transactionSampleCreditNote => 'Grocery purchase';

  @override
  String get transactionSamplePaymentNote => 'Cash received';

  @override
  String get dashboardTitle => 'Account ledger';

  @override
  String get dashboardSubtitle => 'Home';

  @override
  String get dashboardGreetingCaption => 'Good morning, boss,';

  @override
  String get dashboardWelcome => 'Welcome to your shop';

  @override
  String get dashboardTotalOwed => 'Total owed by customers';

  @override
  String dashboardDebtorCount(int count) {
    return '$count customers with an outstanding balance';
  }

  @override
  String get dashboardTodayCollections => 'Today\'s collections';

  @override
  String get dashboardRegisterTransaction => 'Record transaction';

  @override
  String get dashboardNewCustomer => 'New customer';

  @override
  String get dashboardTopDebtors => 'Top debtors';

  @override
  String get dashboardViewAll => 'View all';

  @override
  String get dashboardRecentActivity => 'Recent activity';

  @override
  String get dashboardUpdatedLive => 'Updated live';

  @override
  String dashboardActivityDate(String day, String time) {
    return '$day, $time';
  }

  @override
  String get dashboardTipTitle => 'Your ledger is organized and protected';

  @override
  String get dashboardTipMessage =>
      'Record every penny as it happens so your accounts and your customers\' rights are never lost.';

  @override
  String get statementTitle => 'Customer statement';

  @override
  String get statementLoadError =>
      'Could not load the statement. Please try again.';

  @override
  String get statementShareError =>
      'Could not share the statement. Please try again.';

  @override
  String get statementCopyError =>
      'Could not copy the statement. Please try again.';

  @override
  String get statementCopied => 'Statement copied';

  @override
  String get statementEmpty => 'No transactions in this period.';

  @override
  String get statementSettledHint => 'No outstanding balance';

  @override
  String get statementCreditBalanceHint => 'Credit in the customer\'s favor';

  @override
  String statementPeriodCredit(String amount) {
    return 'Period credit total: $amount';
  }

  @override
  String statementPeriodPayment(String amount) {
    return 'Period payment total: $amount';
  }

  @override
  String get statementPreviewTitle => 'Preview before sending';

  @override
  String get statementPreviewSubtitle =>
      'Review the entries before sharing with your customer.';

  @override
  String get statementMockNotice =>
      'Sample statement — not this customer\'s data. Filters, sharing, and copying are not available in this preview.';

  @override
  String statementGeneratedAt(String date, String time) {
    return 'Generated: $date • $time';
  }

  @override
  String get statementBalance => 'Total outstanding balance';

  @override
  String get statementBalanceHint => 'Please pay the balance or make a payment';

  @override
  String get statementRangeAll => 'All time';

  @override
  String get statementRangeLast30Days => 'Last 30 days';

  @override
  String get statementRangeThisMonth => 'This month';

  @override
  String get statementRangeCustom => 'Custom range';

  @override
  String get statementEntriesTitle => 'Account activity';

  @override
  String get statementFooter =>
      'Thank you for shopping with us. We\'re always happy to help.';

  @override
  String get statementWhatsApp => 'Send via WhatsApp';

  @override
  String get statementCopy => 'Copy text';

  @override
  String get statementShareHint =>
      'Shares statement images. Choose WhatsApp or another app, then send.';

  @override
  String get statementImageTitle => 'Account statement';

  @override
  String get statementImageShare => 'Share statement image';

  @override
  String get statementImageFooter => 'Statement generated by Daftari';

  @override
  String statementImagePage(int page, int total) {
    return '$page / $total';
  }

  @override
  String get statementShareWithCustomer => 'Share statement with customer';

  @override
  String get statementSampleCustomer => 'Mahmoud El Shenawy';

  @override
  String get statementSampleCredit1 => 'Sugar and a carton of oil';

  @override
  String get statementSampleCredit2 => '2 kg of cheese';

  @override
  String get statementSampleCredit3 => 'Household groceries';

  @override
  String get statementSamplePayment1 => 'Cash payment';

  @override
  String get statementSamplePayment2 => 'Cash wallet transfer';

  @override
  String get authLoginTitle => 'Sign in';

  @override
  String get authRegisterTitle => 'Create account';

  @override
  String get authForgotTitle => 'Reset password';

  @override
  String get authVerifyTitle => 'Verify your email';

  @override
  String get authUpdateTitle => 'New password';

  @override
  String get authLoginHeading => 'Protect your data from loss';

  @override
  String get authLoginSubtitle =>
      'Link your local ledger to your account so customer balances and debts are never lost if your phone changes or is lost.';

  @override
  String get authRegisterHeading => 'Protect your data from loss';

  @override
  String get authRegisterSubtitle =>
      'Create your account to link your local ledger for optional secure backup and restore, even if your phone is lost.';

  @override
  String get authForgotHeading => 'Forgot your password?';

  @override
  String get authForgotSubtitle =>
      'Enter your email and we will send you a link to reset your password.';

  @override
  String get authVerifyHeading => 'Check your inbox';

  @override
  String authVerifySubtitle(String email) {
    return 'We sent a verification link to $email. Open it to activate your account.';
  }

  @override
  String get authVerifyGenericSubtitle =>
      'Open the verification link in your email to activate your account.';

  @override
  String get authUpdateHeading => 'Choose a new password';

  @override
  String get authUpdateSubtitle => 'Choose a new password for your account.';

  @override
  String get authSecureBadge => 'Secure encryption';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailHint => 'example@gmail.com';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordHint => 'Enter your password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authCreateAccount => 'Create a new account';

  @override
  String get authShopName => 'Shop / merchant name';

  @override
  String get authShopNameHint => 'e.g. Al-Amana Grocery or Abu Omar';

  @override
  String get authShopNameViewerHint => 'Shown on customer statements';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authRegisterAction => 'Create account and save ledger';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authSignInLink => 'Sign in';

  @override
  String get authRegisterConsent =>
      'By creating an account, you agree to the terms of use and data protection policy. Your ledger data remains yours alone.';

  @override
  String get authOfflineNoteTitle => 'Your ledger always works offline';

  @override
  String get authOfflineNote =>
      'Signing in enables optional secure backup to help protect your ledger if your phone is stolen or damaged.';

  @override
  String get authContinueOffline => 'Continue with local ledger (later)';

  @override
  String get authContinueOfflineHint =>
      'You can keep using the ledger locally and back up later.';

  @override
  String get authLoginMockNotice =>
      'Preview only — sign-in isn\'t available yet.';

  @override
  String get authRegisterMockNotice =>
      'Preview only — account creation isn\'t available yet.';

  @override
  String get authSendResetLink => 'Send reset link';

  @override
  String get authResetSentTitle => 'Check your email';

  @override
  String authResetSentMessage(String email) {
    return 'We sent a password reset link to $email.';
  }

  @override
  String get authBackToLogin => 'Back to sign in';

  @override
  String get authForgotMockNotice => 'Preview only — no email will be sent.';

  @override
  String get authResendVerification => 'Resend verification link';

  @override
  String get authResendSent => 'Verification link sent again.';

  @override
  String get authVerifiedAction => 'I\'ve verified my email';

  @override
  String get authVerifyMockNotice =>
      'Preview only — email verification isn\'t available yet.';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authUpdatePasswordAction => 'Save password';

  @override
  String get authUpdateMockNotice =>
      'Preview only — password update isn\'t available yet.';

  @override
  String get authPasswordMismatch => 'Passwords do not match';

  @override
  String get authShopNameRequired => 'Enter a shop name';

  @override
  String get authLinkDialogTitle => 'Link this ledger to your account?';

  @override
  String get authLinkDialogMessage =>
      'This device\'s local ledger will be linked to your account. Nothing is uploaded yet, and your data stays on your device. Once linked, this device\'s ledger can only be used with this account.';

  @override
  String get authLinkDialogConfirm => 'Link ledger';

  @override
  String get authAccountTitle => 'Account';

  @override
  String get authAccountSignedOutTitle => 'Not signed in';

  @override
  String get authAccountSignedOutDescription =>
      'Link your ledger to an account so your data is never lost.';

  @override
  String get authAccountSignIn => 'Sign in';

  @override
  String get authAccountCreate => 'Create account';

  @override
  String get authAccountLinkedTitle => 'Ledger linked';

  @override
  String authAccountLinkedTo(String email) {
    return 'Linked to $email';
  }

  @override
  String get authAccountVerified => 'Verified';

  @override
  String get authAccountEmailUnverified => 'Email not verified';

  @override
  String get authAccountSignOut => 'Sign out';

  @override
  String get authAccountLocalOnly => 'Your data is stored on this device';

  @override
  String get authAccountMockNotice =>
      'Preview only — account is not connected yet.';

  @override
  String get authAccountSignOutMessage =>
      'Sign out? Your local ledger data will not be deleted.';

  @override
  String get authErrorAccountMismatch =>
      'This device\'s ledger is linked to another account. Sign in with the original account to continue.';

  @override
  String get authErrorAuth =>
      'Authentication failed. Check your email and password and try again.';

  @override
  String get authErrorNetwork =>
      'Could not connect. Check your internet connection and try again.';

  @override
  String get authErrorUnconfigured =>
      'Account sign-in is not configured in this build. Your ledger continues to work locally.';

  @override
  String get authErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get authPasswordUpdated => 'Password updated successfully.';

  @override
  String get authEmailNotVerifiedYet =>
      'Your email is not verified yet. Open the link in your inbox and try again.';

  @override
  String get authSignedOutSuccess =>
      'Signed out. Your local ledger data is safe on this device.';

  @override
  String get authLinkedSuccess => 'Ledger linked to your account.';

  @override
  String get backupSectionTitle => 'Cloud backup';

  @override
  String get backupSyncStatusTitle => 'Cloud sync status';

  @override
  String get backupStatusNeverBackedUp => 'Not backed up yet';

  @override
  String get backupStatusPending => 'Changes pending';

  @override
  String get backupStatusRunning => 'Backing up…';

  @override
  String get backupStatusFailed => 'Backup failed';

  @override
  String get backupStatusUpToDate => 'Connected & secure';

  @override
  String backupLastConfirmed(String day, String time) {
    return 'Last backup: $day, $time';
  }

  @override
  String get backupNeverConfirmed => 'No backup yet';

  @override
  String backupPendingChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes pending',
      one: '1 change pending',
      zero: 'No pending changes',
    );
    return '$_temp0';
  }

  @override
  String get backupFailedHint =>
      'The last attempt didn\'t finish. Your previous backup is safe.';

  @override
  String get backupFailedFirstHint =>
      'The backup attempt didn\'t finish. Your local ledger is safe on this device.';

  @override
  String get backupPreviewBanner =>
      'Preview — cloud backup is not connected yet.';

  @override
  String get backupAccountSignedOutTitle => 'Signed out';

  @override
  String get backupAccountSignedOutSubtitle =>
      'Sign in from Account settings to enable cloud backup.';

  @override
  String get backupNowAction => 'Back up now';

  @override
  String get backupNowTitle => 'Save an instant cloud copy';

  @override
  String get backupNowSubtitle => 'Secure all debts and payments now';

  @override
  String get backupManageTitle => 'Manage backup';

  @override
  String get backupManageSubtitle => 'Backup schedule and status';

  @override
  String get backupScreenTitle => 'Backup settings';

  @override
  String get backupActiveAccount => 'Active account';

  @override
  String get backupScheduleTitle => 'Backup schedule';

  @override
  String get backupScheduleDaily => 'Daily';

  @override
  String get backupScheduleWeekly => 'Weekly';

  @override
  String get backupScheduleMonthly => 'Monthly';

  @override
  String get backupScheduleCaption =>
      'Choose how often to back up automatically when Android allows.';

  @override
  String get backupMockNotice => 'Preview only — backup isn\'t available yet.';
}
