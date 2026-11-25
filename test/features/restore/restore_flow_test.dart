import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/services/date_service.dart';
import 'package:daftariapp/core/services/local_storage_service.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/utils/app_date_utils.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'package:daftariapp/features/backup/presentation/models/backup_view_state.dart';
import 'package:daftariapp/features/backup/presentation/screens/backup_screen.dart';
import 'package:daftariapp/features/backup/presentation/widgets/backup_settings_section.dart';
import 'package:daftariapp/features/restore/data/repositories/fake_restore_repository.dart';
import 'package:daftariapp/features/restore/domain/entities/restore_entities.dart';
import 'package:daftariapp/features/restore/presentation/cubit/restore_cubit.dart';
import 'package:daftariapp/features/restore/presentation/cubit/restore_state.dart';
import 'package:daftariapp/features/restore/presentation/screens/restore_screen.dart';
import 'package:daftariapp/features/restore/presentation/widgets/restore_labels.dart';
import 'package:daftariapp/features/security/domain/entities/pin_verify_result.dart';
import 'package:daftariapp/features/security/domain/entities/security_settings.dart';
import 'package:daftariapp/features/security/domain/policies/pin_lockout_policy.dart';
import 'package:daftariapp/features/security/domain/repositories/security_repository.dart';
import 'package:daftariapp/features/security/presentation/cubit/app_lock_cubit.dart';
import 'package:daftariapp/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_theme_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_test_fakes.dart';

const _accountA = RestoreAccountInfo(
  userId: 'user-a',
  email: 'shop@example.com',
  shopName: 'Al-Amana Grocery',
  isEmailVerified: true,
);

const _authUserA = AuthUser(
  id: 'user-a',
  email: 'shop@example.com',
  shopName: 'Al-Amana Grocery',
  emailVerified: true,
);

final _confirmedAt = DateTime.utc(2026, 11, 25, 9, 30);

CloudBackupSnapshotPreview _cloudSnapshot({
  String version = 'v-1',
  String ownerUserId = 'user-a',
  String activeDeviceId = 'device-previous-phone',
  DateTime? confirmedAt,
  int customerCount = 7,
  int deletedCustomerCount = 0,
  int transactionCount = 42,
  int deletedTransactionCount = 0,
  int auditLogCount = 3,
}) => CloudBackupSnapshotPreview(
  version: version,
  ownerUserId: ownerUserId,
  activeDeviceId: activeDeviceId,
  confirmedAt: confirmedAt ?? _confirmedAt,
  customerCount: customerCount,
  deletedCustomerCount: deletedCustomerCount,
  transactionCount: transactionCount,
  deletedTransactionCount: deletedTransactionCount,
  auditLogCount: auditLogCount,
);

RestoreLocalLedgerSummary _emptyLocalLedger({
  String deviceId = 'device-new-phone',
  String? linkedOwnerUserId,
  bool isActiveDevice = true,
}) => RestoreLocalLedgerSummary(
  deviceId: deviceId,
  linkedOwnerUserId: linkedOwnerUserId,
  isActiveDevice: isActiveDevice,
);

RestoreLocalLedgerSummary _populatedLocalLedger({
  String deviceId = 'device-new-phone',
  String? linkedOwnerUserId = 'user-a',
  bool isActiveDevice = true,
  int customerCount = 3,
  int deletedCustomerCount = 0,
  int transactionCount = 8,
  int deletedTransactionCount = 0,
  int auditLogCount = 1,
  int pendingChangesCount = 2,
  String revisionStamp = 'rev-1',
}) => RestoreLocalLedgerSummary(
  deviceId: deviceId,
  linkedOwnerUserId: linkedOwnerUserId,
  isActiveDevice: isActiveDevice,
  customerCount: customerCount,
  deletedCustomerCount: deletedCustomerCount,
  transactionCount: transactionCount,
  deletedTransactionCount: deletedTransactionCount,
  auditLogCount: auditLogCount,
  pendingChangesCount: pendingChangesCount,
  revisionStamp: revisionStamp,
);

Future<void> _pumpRestore(
  WidgetTester tester,
  Widget child, {
  String locale = 'ar',
  ThemeMode themeMode = ThemeMode.light,
  Size size = const Size(400, 900),
  List<BlocProvider> providers = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = ScreenUtilInit(
    designSize: AppConstants.designSize,
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, _) => MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppConstants.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: child,
    ),
  );
  await tester.pumpWidget(
    providers.isEmpty
        ? app
        : MultiBlocProvider(providers: providers, child: app),
  );
  await tester.pump();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

class _LockedSecurityRepository implements SecurityRepository {
  @override
  Future<Either<AppFailure, SecuritySettings>> getSettings() async =>
      const Right(
        SecuritySettings(
          isPinEnabled: true,
          autoLockTimeout: AutoLockTimeout.immediate,
        ),
      );

  @override
  Future<Either<AppFailure, PinLockoutState>> getLockoutState() async =>
      const Right(PinLockoutState.clear());

  @override
  Future<Either<AppFailure, void>> setupPin(String pin) async =>
      const Right(null);

  @override
  Future<Either<AppFailure, PinVerifyResult>> verifyPin(String pin) async =>
      Right(
        pin == '1234'
            ? const PinVerified()
            : const PinIncorrect(remainingAttempts: 4),
      );

  @override
  Future<Either<AppFailure, PinVerifyResult>> changePin({
    required String currentPin,
    required String newPin,
  }) => verifyPin(currentPin);

  @override
  Future<Either<AppFailure, PinVerifyResult>> disablePin(String pin) =>
      verifyPin(pin);

  @override
  Future<Either<AppFailure, bool>> canAuthenticateWithBiometrics() async =>
      const Right(false);

  @override
  Future<Either<AppFailure, bool>> isDeviceLockSupported() async =>
      const Right(false);

  @override
  Future<Either<AppFailure, bool>> authenticateWithBiometrics() async =>
      const Right(false);

  @override
  Future<Either<AppFailure, bool>> authorizePinReset() async =>
      const Right(false);

  @override
  void cancelPinReset() {}

  @override
  Future<Either<AppFailure, bool>> resetPinWithDeviceCredential(
    String newPin,
  ) async => const Right(false);

  @override
  Future<Either<AppFailure, bool>> setBiometricEnabled(bool enabled) async =>
      const Right(false);

  @override
  Future<Either<AppFailure, void>> setAutoLockTimeout(
    AutoLockTimeout timeout,
  ) async => const Right(null);
}

void main() {
  setUpAll(AppDateUtils.initialize);

  group('Settings → Backup → Restore entry, PIN and account checks', () {
    for (final locale in ['ar', 'en']) {
      testWidgets(
        'navigates from BackupScreen to RestoreScreen and displays preview in $locale',
        (tester) async {
          final repo = FakeRestoreRepository(
            account: _accountA,
            localLedger: _emptyLocalLedger(),
            cloudPreview: _cloudSnapshot(),
          );
          final cubit = RestoreCubit(repository: repo);
          addTearDown(cubit.close);

          await _pumpRestore(
            tester,
            BackupScreen(
              state: BackupViewState(
                status: BackupStatus.upToDate,
                pendingChanges: 0,
                lastConfirmedAt: _confirmedAt,
                accountEmail: _accountA.email,
                accountShopName: _accountA.shopName,
              ),
            ),
            locale: locale,
            providers: [BlocProvider<RestoreCubit>.value(value: cubit)],
          );

          expect(find.byKey(const ValueKey('backup-restore')), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('backup-restore')));
          await tester.pumpAndSettle();

          final context = tester.element(find.byType(RestoreScreen));
          final l10n = context.l10n;
          expect(find.byType(RestoreScreen), findsOneWidget);
          expect(find.text(l10n.restoreScreenTitle), findsOneWidget);
          expect(find.text(_accountA.shopName!), findsOneWidget);
          expect(find.text(_accountA.email), findsOneWidget);
          expect(
            find.text(_confirmedAt.confirmedAtLabel(context)),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('restore-consequence-card')),
            findsOneWidget,
          );
          expect(
            find.text(l10n.restorePreviousPhonePendingWarning),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'fresh signed-out and signed-in default preview never fabricates sample merchant or timestamp in $locale',
        (tester) async {
          final signedOutBackend = FakeAuthBackend();
          final signedOutCubit = await createInitializedSessionCubit(
            signedOutBackend,
          );
          addTearDown(() async {
            await signedOutCubit.close();
            await signedOutBackend.dispose();
          });

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: locale,
            providers: [
              BlocProvider<AuthSessionCubit>.value(value: signedOutCubit),
            ],
          );

          var l10n = tester.element(find.byType(RestoreScreen)).l10n;
          expect(
            find.byKey(const ValueKey('backup-preview-banner')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('restore-state-signed-out')),
            findsOneWidget,
          );
          expect(find.text(l10n.backupAccountSignedOutTitle), findsOneWidget);
          expect(find.text(l10n.restoreSignedOutTitle), findsOneWidget);
          expect(
            find.byKey(const ValueKey('restore-start-button')),
            findsNothing,
          );

          final unverifiedBackend = FakeAuthBackend(
            currentUser: const AuthUser(
              id: 'user-unverified',
              email: 'pending@example.com',
              shopName: 'Pending Shop',
              emailVerified: false,
            ),
          );
          final unverifiedCubit = await createInitializedSessionCubit(
            unverifiedBackend,
          );
          addTearDown(() async {
            await unverifiedCubit.close();
            await unverifiedBackend.dispose();
          });

          final unverifiedRepo = FakeRestoreRepository(
            readAuthState: () => unverifiedCubit.state,
          );
          final restoreCubit = RestoreCubit(repository: unverifiedRepo);
          addTearDown(restoreCubit.close);

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: locale,
            providers: [
              BlocProvider<AuthSessionCubit>.value(value: unverifiedCubit),
              BlocProvider<RestoreCubit>.value(value: restoreCubit),
            ],
          );
          await tester.pump();

          l10n = tester.element(find.byType(RestoreScreen)).l10n;
          expect(
            find.byKey(const ValueKey('restore-state-email-unverified')),
            findsOneWidget,
          );
          expect(find.text(l10n.restoreEmailUnverifiedTitle), findsOneWidget);
          expect(
            find.byKey(const ValueKey('restore-start-button')),
            findsNothing,
          );
        },
      );
    }

    testWidgets(
      'AppRouter enforces PIN lock guard before allowing navigation to settingsRestore',
      (tester) async {
        SharedPreferences.setMockInitialValues({'onboarding_completed': true});
        final prefs = await SharedPreferences.getInstance();
        final localStorage = LocalStorageService(prefs);
        final appLock = AppLockCubit(
          _LockedSecurityRepository(),
          SystemDateService(),
        );
        await appLock.initialize();
        addTearDown(appLock.close);
        expect(appLock.state.locked, isTrue);

        final backend = FakeAuthBackend(
          currentUser: _authUserA,
          linkedUserId: _authUserA.id,
        );
        final authCubit = await createInitializedSessionCubit(backend);
        addTearDown(() async {
          await authCubit.close();
          await backend.dispose();
        });

        final settingsRepo = SettingsRepositoryImpl(localStorage);
        final settingsCubit = SettingsCubit(
          GetSettingsUseCase(settingsRepo),
          ChangeLanguageUseCase(settingsRepo),
          ChangeThemeUseCase(settingsRepo),
          ErrorHandler(AppLogger(output: (_) {}, enableCrashReporting: false)),
        );
        addTearDown(settingsCubit.close);

        final restoreRepo = FakeRestoreRepository(
          account: _accountA,
          cloudPreview: _cloudSnapshot(),
        );
        final router = AppRouter.create(
          localStorage: localStorage,
          appLock: appLock,
          authSessionCubit: authCubit,
          createRestoreCubit: () => RestoreCubit(repository: restoreRepo),
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<AppLockCubit>.value(value: appLock),
              BlocProvider<AuthSessionCubit>.value(value: authCubit),
              BlocProvider<SettingsCubit>.value(value: settingsCubit),
            ],
            child: ScreenUtilInit(
              designSize: AppConstants.designSize,
              builder: (context, _) => MaterialApp.router(
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppConstants.supportedLocales,
                theme: AppTheme.light,
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pump();

        router.go(AppRoutes.settingsRestore);
        await tester.pumpAndSettle();

        // While locked, router redirects to /lock and does not open RestoreScreen.
        expect(router.state.uri.path, AppRoutes.lock);
        expect(find.byType(RestoreScreen), findsNothing);

        // Unlock with valid PIN, then navigate to Settings → Backup → Restore.
        await appLock.verify('1234');
        await tester.pumpAndSettle();
        expect(appLock.state.locked, isFalse);

        router.go(AppRoutes.settingsRestore);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, AppRoutes.settingsRestore);
        expect(find.byType(RestoreScreen), findsOneWidget);
      },
    );
  });

  group('Missing backup, zero-row confirmed snapshot, offline and account mismatch', () {
    for (final locale in ['ar', 'en']) {
      testWidgets(
        'missing backup shows missing-backup state while zero-row confirmed snapshot is restorable in $locale',
        (tester) async {
          final repo = FakeRestoreRepository(
            account: _accountA,
            localLedger: _emptyLocalLedger(),
            cloudPreview: null,
          );
          final cubit = RestoreCubit(repository: repo);
          addTearDown(cubit.close);

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: locale,
            providers: [BlocProvider<RestoreCubit>.value(value: cubit)],
          );
          await tester.pump();

          final l10n = tester.element(find.byType(RestoreScreen)).l10n;
          expect(
            find.byKey(const ValueKey('restore-state-missing-backup')),
            findsOneWidget,
          );
          expect(find.text(l10n.restoreMissingBackupTitle), findsOneWidget);
          expect(find.text(l10n.restoreMissingBackupMessage), findsOneWidget);
          expect(
            find.byKey(const ValueKey('restore-start-button')),
            findsNothing,
          );

          // Now configure a valid confirmed snapshot with ZERO rows and retry.
          repo.cloudPreview = _cloudSnapshot(
            version: 'v-zero',
            customerCount: 0,
            transactionCount: 0,
            auditLogCount: 0,
          );
          await tester.tap(find.byKey(const ValueKey('restore-retry')));
          await tester.pump();

          expect(
            find.byKey(const ValueKey('restore-state-missing-backup')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('restore-cloud-preview-card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('restore-zero-rows-note')),
            findsOneWidget,
          );
          expect(find.text(l10n.restoreZeroRowsSnapshotNote), findsOneWidget);
          expect(
            find.byKey(const ValueKey('restore-start-button')),
            findsOneWidget,
          );

          // Confirming restore of the zero-row snapshot succeeds cleanly.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-start-button')),
          );
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-primary-confirm')),
          );

          expect(
            find.byKey(const ValueKey('restore-state-completed')),
            findsOneWidget,
          );
          expect(repo.completedRestoreCount, 1);
          expect(repo.localLedger.totalRecordCount, 0);
          expect(repo.localLedger.pendingChangesCount, 0);
        },
      );

      testWidgets(
        'offline state blocks preview and recovers via retry when back online in $locale',
        (tester) async {
          final repo = FakeRestoreRepository(
            account: _accountA,
            localLedger: _populatedLocalLedger(),
            cloudPreview: _cloudSnapshot(),
            isOnline: false,
          );
          final cubit = RestoreCubit(repository: repo);
          addTearDown(cubit.close);

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: locale,
            providers: [BlocProvider<RestoreCubit>.value(value: cubit)],
          );
          await tester.pump();

          final l10n = tester.element(find.byType(RestoreScreen)).l10n;
          expect(
            find.byKey(const ValueKey('restore-state-offline')),
            findsOneWidget,
          );
          expect(find.text(l10n.restoreOfflineTitle), findsOneWidget);
          expect(find.text(l10n.restoreOfflineMessage), findsOneWidget);
          expect(
            find.byKey(const ValueKey('restore-start-button')),
            findsNothing,
          );
          expect(repo.localLedger.customerCount, 3);
          expect(repo.localLedger.pendingChangesCount, 2);

          repo.isOnline = true;
          await tester.tap(find.byKey(const ValueKey('restore-retry')));
          await tester.pump();

          expect(
            find.byKey(const ValueKey('restore-state-offline')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('restore-cloud-preview-card')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('restore-start-button')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'different linked owner blocks restore and preserves local ledger in $locale',
        (tester) async {
          final originalLedger = _populatedLocalLedger(
            linkedOwnerUserId: 'user-other-owner',
            customerCount: 5,
            transactionCount: 12,
            pendingChangesCount: 4,
          );
          final repo = FakeRestoreRepository(
            account: _accountA,
            localLedger: originalLedger,
            cloudPreview: _cloudSnapshot(),
          );
          final cubit = RestoreCubit(repository: repo);
          addTearDown(cubit.close);

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: locale,
            providers: [BlocProvider<RestoreCubit>.value(value: cubit)],
          );
          await tester.pump();

          final l10n = tester.element(find.byType(RestoreScreen)).l10n;
          expect(
            find.byKey(const ValueKey('restore-state-account-mismatch')),
            findsOneWidget,
          );
          expect(find.text(l10n.restoreAccountMismatchTitle), findsOneWidget);
          expect(find.text(l10n.restoreAccountMismatchMessage), findsOneWidget);
          expect(
            find.byKey(const ValueKey('restore-start-button')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('restore-primary-confirmation')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('restore-replacement-confirmation')),
            findsNothing,
          );
          expect(repo.localLedger, originalLedger);
          expect(repo.completedRestoreCount, 0);
        },
      );
    }
  });

  group('Confirmation gating for empty vs populated ledgers and new vs active phones', () {
    for (final locale in ['ar', 'en']) {
      testWidgets(
        'new phone with empty ledger confirms restore and takeover together in one confirmation in $locale',
        (tester) async {
          final repo = FakeRestoreRepository(
            account: _accountA,
            localLedger: _emptyLocalLedger(deviceId: 'device-new'),
            cloudPreview: _cloudSnapshot(activeDeviceId: 'device-old'),
          );
          final cubit = RestoreCubit(repository: repo);
          addTearDown(cubit.close);

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: locale,
            providers: [BlocProvider<RestoreCubit>.value(value: cubit)],
          );
          await tester.pump();

          final l10n = tester.element(find.byType(RestoreScreen)).l10n;
          expect(find.text(l10n.restoreConsequenceTakeover), findsOneWidget);
          expect(
            find.text(l10n.restorePreviousPhonePendingWarning),
            findsOneWidget,
          );
          expect(find.text(l10n.restoreLocalEmptyTitle), findsOneWidget);
          expect(find.text(l10n.restoreAndTransferAction), findsOneWidget);

          // Step 1: open primary confirmation. Nothing executed yet.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-start-button')),
          );

          expect(
            find.byKey(const ValueKey('restore-primary-confirmation')),
            findsOneWidget,
          );
          expect(find.text(l10n.restoreConfirmTakeoverTitle), findsOneWidget);
          expect(find.text(l10n.restoreConfirmTakeoverMessage), findsOneWidget);
          expect(
            find.byKey(const ValueKey('restore-replacement-confirmation')),
            findsNothing,
          );
          expect(repo.executeCalls, 0);

          // Step 2: confirm primary confirmation -> executes restore + takeover.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-primary-confirm')),
          );

          expect(
            find.byKey(const ValueKey('restore-state-completed')),
            findsOneWidget,
          );
          expect(
            find.text(l10n.restoreCompletedTransferredMessage),
            findsOneWidget,
          );
          expect(repo.executeCalls, 1);
          expect(repo.completedRestoreCount, 1);
          expect(repo.completedTakeoverCount, 1);
          expect(repo.cloudPreview!.activeDeviceId, 'device-new');
          expect(repo.localLedger.linkedOwnerUserId, _accountA.userId);
          expect(repo.localLedger.customerCount, 7);
          expect(repo.localLedger.transactionCount, 42);
          expect(repo.localLedger.pendingChangesCount, 0);
        },
      );

      testWidgets(
        'existing active phone with empty ledger restores in one confirmation without authority change in $locale',
        (tester) async {
          final repo = FakeRestoreRepository(
            account: _accountA,
            localLedger: _emptyLocalLedger(
              deviceId: 'device-active',
              linkedOwnerUserId: _accountA.userId,
            ),
            cloudPreview: _cloudSnapshot(activeDeviceId: 'device-active'),
          );
          final cubit = RestoreCubit(repository: repo);
          addTearDown(cubit.close);

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: locale,
            providers: [BlocProvider<RestoreCubit>.value(value: cubit)],
          );
          await tester.pump();

          final l10n = tester.element(find.byType(RestoreScreen)).l10n;
          expect(find.text(l10n.restoreConsequenceSameDevice), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('restore-start-button')),
              matching: find.text(l10n.restoreOnlyAction),
            ),
            findsOneWidget,
          );

          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-start-button')),
          );

          expect(
            find.byKey(const ValueKey('restore-primary-confirmation')),
            findsOneWidget,
          );
          expect(find.text(l10n.restoreConfirmSameDeviceTitle), findsOneWidget);
          expect(
            find.text(l10n.restoreConfirmSameDeviceButton),
            findsOneWidget,
          );

          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-primary-confirm')),
          );

          expect(
            find.byKey(const ValueKey('restore-state-completed')),
            findsOneWidget,
          );
          expect(
            find.text(l10n.restoreCompletedSameDeviceMessage),
            findsOneWidget,
          );
          expect(repo.completedRestoreCount, 1);
          expect(repo.completedTakeoverCount, 0);
          expect(cubit.state.authorityTransferred, isFalse);
        },
      );

      testWidgets(
        'populated ledger linked to same account requires second confirmation showing local counts and pending changes in $locale',
        (tester) async {
          final initialLocal = _populatedLocalLedger(
            deviceId: 'device-new',
            linkedOwnerUserId: _accountA.userId,
            customerCount: 4,
            transactionCount: 11,
            auditLogCount: 2,
            pendingChangesCount: 3,
          );
          final repo = FakeRestoreRepository(
            account: _accountA,
            localLedger: initialLocal,
            cloudPreview: _cloudSnapshot(activeDeviceId: 'device-old'),
          );
          final cubit = RestoreCubit(repository: repo);
          addTearDown(cubit.close);

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: locale,
            providers: [BlocProvider<RestoreCubit>.value(value: cubit)],
          );
          await tester.pump();

          final l10n = tester.element(find.byType(RestoreScreen)).l10n;
          expect(find.text(l10n.restoreLocalPopulatedTitle), findsOneWidget);
          expect(find.text(l10n.restoreLocalPopulatedWarning), findsOneWidget);
          expect(find.text(l10n.restoreCustomersCount(4)), findsOneWidget);
          expect(find.text(l10n.restoreTransactionsCount(11)), findsOneWidget);
          expect(find.text(l10n.restoreHistoryCount(2)), findsOneWidget);
          expect(find.text(l10n.backupPendingChanges(3)), findsOneWidget);

          // Step 1: tap start -> primary confirmation opens.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-start-button')),
          );
          expect(
            find.byKey(const ValueKey('restore-primary-confirmation')),
            findsOneWidget,
          );
          expect(repo.executeCalls, 0);
          expect(repo.localLedger, initialLocal);

          // Step 2: tap primary confirm -> does NOT execute replacement!
          // Advances to the second explicit replacement confirmation.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-primary-confirm')),
          );

          expect(repo.executeCalls, 0);
          expect(repo.completedRestoreCount, 0);
          expect(repo.localLedger, initialLocal);
          expect(
            find.byKey(const ValueKey('restore-primary-confirmation')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('restore-replacement-confirmation')),
            findsOneWidget,
          );
          expect(
            find.text(l10n.restoreReplacementConfirmTitle),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(
                const ValueKey('restore-replacement-local-counts'),
              ),
              matching: find.text(l10n.restoreCustomersCount(4)),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(
                const ValueKey('restore-replacement-local-counts'),
              ),
              matching: find.text(l10n.restoreTransactionsCount(11)),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(
                const ValueKey('restore-replacement-local-counts'),
              ),
              matching: find.text(l10n.backupPendingChanges(3)),
            ),
            findsOneWidget,
          );

          // Step 3: tap second replacement confirm -> permits and executes replacement.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-replacement-confirm')),
          );

          expect(
            find.byKey(const ValueKey('restore-state-completed')),
            findsOneWidget,
          );
          expect(repo.executeCalls, 1);
          expect(repo.completedRestoreCount, 1);
          expect(repo.completedTakeoverCount, 1);
          expect(repo.localLedger.customerCount, 7);
          expect(repo.localLedger.transactionCount, 42);
          expect(repo.localLedger.pendingChangesCount, 0);
        },
      );
    }

    testWidgets(
      'ledger containing only deleted records or only audit history counts as populated and requires second confirmation',
      (tester) async {
        for (final localCase in [
          _populatedLocalLedger(
            customerCount: 0,
            deletedCustomerCount: 1,
            transactionCount: 0,
            deletedTransactionCount: 0,
            auditLogCount: 0,
            pendingChangesCount: 1,
          ),
          _populatedLocalLedger(
            customerCount: 0,
            deletedCustomerCount: 0,
            transactionCount: 0,
            deletedTransactionCount: 0,
            auditLogCount: 2,
            pendingChangesCount: 0,
          ),
        ]) {
          expect(localCase.isPopulated, isTrue);
          final repo = FakeRestoreRepository(
            account: _accountA,
            localLedger: localCase,
            cloudPreview: _cloudSnapshot(),
          );
          final cubit = RestoreCubit(repository: repo);

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: 'en',
            providers: [BlocProvider<RestoreCubit>.value(value: cubit)],
          );
          await tester.pump();

          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-start-button')),
          );
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-primary-confirm')),
          );

          // First confirmation alone must not replace a tombstone/audit-only ledger.
          expect(repo.executeCalls, 0);
          expect(repo.localLedger, localCase);
          expect(
            find.byKey(const ValueKey('restore-replacement-confirmation')),
            findsOneWidget,
          );

          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-replacement-confirm')),
          );

          expect(repo.executeCalls, 1);
          expect(repo.completedRestoreCount, 1);
          await cubit.close();
        }
      },
    );

    test('repository rejects executeRestore when replacement confirmation is missing for a populated ledger', () async {
      final originalLocal = _populatedLocalLedger();
      final repo = FakeRestoreRepository(
        account: _accountA,
        localLedger: originalLocal,
        cloudPreview: _cloudSnapshot(),
      );
      final unconsentedReplacementToken = RestoreConsentToken(
        version: 'v-1',
        activeDeviceId: 'device-previous-phone',
        confirmedAt: _confirmedAt,
        ownerUserId: _accountA.userId,
        localDeviceId: originalLocal.deviceId,
        localRevisionStamp: originalLocal.revisionStamp,
        requiresTakeover: true,
        requiresReplacement: true,
        primaryConfirmed: true,
        replacementConfirmed: false,
      );

      expect(unconsentedReplacementToken.isFullyPermitted, isFalse);
      final result = await repo.executeRestore(
        consent: unconsentedReplacementToken,
      );
      expect(
        result,
        const Left<AppFailure, RestoreExecutionResult>(
          AppFailure(AppErrorCode.validation),
        ),
      );
      expect(repo.localLedger, originalLocal);
      expect(repo.completedRestoreCount, 0);
    });
  });

  group('Cancellation, stale consent invalidation and recovery after interruption', () {
    for (final locale in ['ar', 'en']) {
      testWidgets(
        'cancelling at first or second confirmation leaves populated local ledger intact in $locale',
        (tester) async {
          final originalLocal = _populatedLocalLedger(
            customerCount: 6,
            transactionCount: 19,
            pendingChangesCount: 4,
          );
          final repo = FakeRestoreRepository(
            account: _accountA,
            localLedger: originalLocal,
            cloudPreview: _cloudSnapshot(),
          );
          final cubit = RestoreCubit(repository: repo);
          addTearDown(cubit.close);

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: locale,
            providers: [BlocProvider<RestoreCubit>.value(value: cubit)],
          );
          await tester.pump();

          // Cancel at first confirmation.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-start-button')),
          );
          expect(
            find.byKey(const ValueKey('restore-primary-confirmation')),
            findsOneWidget,
          );

          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-primary-cancel')),
          );

          expect(
            find.byKey(const ValueKey('restore-primary-confirmation')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('restore-start-button')),
            findsOneWidget,
          );
          expect(repo.executeCalls, 0);
          expect(repo.localLedger, originalLocal);

          // Confirm first confirmation, then cancel at second replacement confirmation.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-start-button')),
          );
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-primary-confirm')),
          );
          expect(
            find.byKey(const ValueKey('restore-replacement-confirmation')),
            findsOneWidget,
          );

          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-replacement-cancel')),
          );

          expect(
            find.byKey(const ValueKey('restore-replacement-confirmation')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('restore-start-button')),
            findsOneWidget,
          );
          expect(repo.executeCalls, 0);
          expect(repo.completedRestoreCount, 0);
          expect(repo.localLedger, originalLocal);
        },
      );

      testWidgets(
        'new local edit after preview invalidates replacement consent, refreshes counts and requires re-confirmation in $locale',
        (tester) async {
          final repo = FakeRestoreRepository(
            account: _accountA,
            localLedger: _populatedLocalLedger(
              customerCount: 2,
              transactionCount: 5,
              pendingChangesCount: 1,
            ),
            cloudPreview: _cloudSnapshot(),
          );
          final cubit = RestoreCubit(repository: repo);
          addTearDown(cubit.close);

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: locale,
            providers: [BlocProvider<RestoreCubit>.value(value: cubit)],
          );
          await tester.pump();

          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-start-button')),
          );
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-primary-confirm')),
          );

          // Local edit happens while user is on the replacement confirmation step.
          repo.recordLocalEdit(
            addedCustomers: 1,
            addedTransactions: 2,
            addedPendingChanges: 3,
          );

          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-replacement-confirm')),
          );

          // Prior consent is invalidated: local ledger is NOT replaced and preview refreshes.
          final l10n = tester.element(find.byType(RestoreScreen)).l10n;
          expect(repo.completedRestoreCount, 0);
          expect(repo.localLedger.customerCount, 3);
          expect(repo.localLedger.transactionCount, 7);
          expect(repo.localLedger.pendingChangesCount, 4);
          expect(
            find.byKey(const ValueKey('restore-refresh-notice')),
            findsOneWidget,
          );
          expect(
            find.text(l10n.restoreLocalLedgerChangedNotice),
            findsOneWidget,
          );
          expect(find.text(l10n.restoreCustomersCount(3)), findsOneWidget);
          expect(find.text(l10n.restoreTransactionsCount(7)), findsOneWidget);
          expect(find.text(l10n.backupPendingChanges(4)), findsOneWidget);

          // Re-confirming both steps with the updated local revision now succeeds.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-start-button')),
          );
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-primary-confirm')),
          );
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-replacement-confirm')),
          );

          expect(
            find.byKey(const ValueKey('restore-state-completed')),
            findsOneWidget,
          );
          expect(repo.completedRestoreCount, 1);
        },
      );

      testWidgets(
        'cloud version or active device change after preview refreshes preview and asks again in $locale',
        (tester) async {
          final repo = FakeRestoreRepository(
            account: _accountA,
            localLedger: _emptyLocalLedger(deviceId: 'device-new'),
            cloudPreview: _cloudSnapshot(
              version: 'v-1',
              customerCount: 7,
              transactionCount: 42,
            ),
          );
          final cubit = RestoreCubit(repository: repo);
          addTearDown(cubit.close);

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: locale,
            providers: [BlocProvider<RestoreCubit>.value(value: cubit)],
          );
          await tester.pump();

          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-start-button')),
          );

          // Another batch is confirmed on the server before takeover commits.
          final newerConfirmedAt = DateTime.utc(2026, 11, 25, 10, 45);
          repo.updateCloudSnapshot(
            version: 'v-2',
            confirmedAt: newerConfirmedAt,
            customerCount: 9,
            transactionCount: 50,
          );

          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-primary-confirm')),
          );

          final l10n = tester.element(find.byType(RestoreScreen)).l10n;
          expect(repo.completedRestoreCount, 0);
          expect(repo.localLedger.isEmpty, isTrue);
          expect(
            find.byKey(const ValueKey('restore-refresh-notice')),
            findsOneWidget,
          );
          expect(
            find.text(l10n.restoreCloudVersionChangedNotice),
            findsOneWidget,
          );
          expect(find.text(l10n.restoreCustomersCount(9)), findsOneWidget);
          expect(find.text(l10n.restoreTransactionsCount(50)), findsOneWidget);

          // Confirming the refreshed v-2 preview succeeds.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-start-button')),
          );
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-primary-confirm')),
          );

          expect(
            find.byKey(const ValueKey('restore-state-completed')),
            findsOneWidget,
          );
          expect(repo.completedRestoreCount, 1);
          expect(repo.localLedger.customerCount, 9);
          expect(repo.localLedger.transactionCount, 50);
        },
      );

      testWidgets(
        'interruption preserves intact ledger, blocks uploads and recovers safely across restart in $locale',
        (tester) async {
          final originalLocal = _populatedLocalLedger(
            deviceId: 'device-new',
            customerCount: 2,
            transactionCount: 4,
            pendingChangesCount: 1,
          );
          final repo =
              FakeRestoreRepository(
                  account: _accountA,
                  localLedger: originalLocal,
                  cloudPreview: _cloudSnapshot(activeDeviceId: 'device-old'),
                )
                ..interruptNextExecutionAtStage =
                    RestoreTransferStage.takeoverConfirmed;

          final firstCubit = RestoreCubit(repository: repo);

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: locale,
            providers: [BlocProvider<RestoreCubit>.value(value: firstCubit)],
          );
          await tester.pump();

          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-start-button')),
          );
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-primary-confirm')),
          );
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-replacement-confirm')),
          );

          // Interrupted after server takeover commit: local ledger is still intact,
          // uploads are blocked, and recovery UI is shown.
          expect(repo.completedRestoreCount, 0);
          expect(repo.localLedger, originalLocal);
          expect(repo.areUploadsBlocked, isTrue);
          expect(
            find.byKey(const ValueKey('restore-state-interrupted')),
            findsOneWidget,
          );
          await firstCubit.close();

          // Simulate app restart with a fresh RestoreCubit reading persisted state.
          final restartedCubit = RestoreCubit(repository: repo);
          addTearDown(restartedCubit.close);

          await _pumpRestore(
            tester,
            const RestoreScreen(),
            locale: locale,
            providers: [
              BlocProvider<RestoreCubit>.value(value: restartedCubit),
            ],
          );
          await tester.pump();

          final l10n = tester.element(find.byType(RestoreScreen)).l10n;
          expect(
            find.byKey(const ValueKey('restore-state-interrupted')),
            findsOneWidget,
          );
          expect(find.text(l10n.restoreInterruptedTitle), findsOneWidget);
          expect(
            find.text(l10n.restoreInterruptedUploadsBlockedNote),
            findsOneWidget,
          );

          // Resume recovery -> finishes installation for the same transfer request.
          await _tapVisible(
            tester,
            find.byKey(const ValueKey('restore-resume-transfer')),
          );

          expect(
            find.byKey(const ValueKey('restore-state-completed')),
            findsOneWidget,
          );
          expect(repo.resumeCalls, 1);
          expect(repo.completedRestoreCount, 1);
          expect(repo.completedTakeoverCount, 1);
          expect(repo.areUploadsBlocked, isFalse);
          expect(repo.localLedger.customerCount, 7);
          expect(repo.localLedger.transactionCount, 42);
          expect(repo.localLedger.pendingChangesCount, 0);
        },
      );
    }

    testWidgets(
      'pre-takeover interrupted transfer can be cancelled cleanly leaving local ledger intact',
      (tester) async {
        final originalLocal = _emptyLocalLedger(deviceId: 'device-new');
        final repo = FakeRestoreRepository(
          account: _accountA,
          localLedger: originalLocal,
          cloudPreview: _cloudSnapshot(activeDeviceId: 'device-old'),
        )..interruptNextExecutionAtStage = RestoreTransferStage.takeoverPending;
        final cubit = RestoreCubit(repository: repo);
        addTearDown(cubit.close);

        await _pumpRestore(
          tester,
          const RestoreScreen(),
          locale: 'en',
          providers: [BlocProvider<RestoreCubit>.value(value: cubit)],
        );
        await tester.pump();

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('restore-start-button')),
        );
        await _tapVisible(
          tester,
          find.byKey(const ValueKey('restore-primary-confirm')),
        );

        expect(
          find.byKey(const ValueKey('restore-state-interrupted')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('restore-cancel-interrupted')),
          findsOneWidget,
        );

        await _tapVisible(
          tester,
          find.byKey(const ValueKey('restore-cancel-interrupted')),
        );

        expect(repo.discardCalls, 1);
        expect(repo.areUploadsBlocked, isFalse);
        expect(repo.localLedger, originalLocal);
        expect(
          find.byKey(const ValueKey('restore-start-button')),
          findsOneWidget,
        );
      },
    );
  });

  group('Responsive RTL/LTR, dark theme, and inactive-device states', () {
    for (final locale in ['ar', 'en']) {
      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets(
          'inactive-device backup state and all restore states render without overflow in $locale (${themeMode.name})',
          (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = 1.6;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );

            final inactiveBackupState = BackupViewState(
              status: BackupStatus.pending,
              pendingChanges: 3,
              lastConfirmedAt: _confirmedAt,
              accountEmail: _accountA.email,
              accountShopName: _accountA.shopName,
              isInactiveDevice: true,
            );

            await _pumpRestore(
              tester,
              BackupScreen(state: inactiveBackupState),
              locale: locale,
              themeMode: themeMode,
              size: const Size(320, 640),
            );
            var l10n = tester.element(find.byType(BackupScreen)).l10n;
            expect(
              find.byKey(const ValueKey('backup-inactive-device-hint')),
              findsOneWidget,
            );
            expect(find.text(l10n.backupInactiveDeviceHint), findsOneWidget);
            expect(inactiveBackupState.canBackUpNow, isFalse);
            expect(tester.takeException(), isNull);

            await _pumpRestore(
              tester,
              Scaffold(
                body: SingleChildScrollView(
                  child: BackupSettingsSection(state: inactiveBackupState),
                ),
              ),
              locale: locale,
              themeMode: themeMode,
              size: const Size(320, 640),
            );
            expect(
              find.byKey(const ValueKey('backup-inactive-device-hint')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);

            final preview = _cloudSnapshot();
            final populated = _populatedLocalLedger();
            final statesToVerify = [
              RestoreViewState(
                phase: RestorePhase.previewReady,
                account: _accountA,
                localLedger: populated,
                cloudPreview: preview,
              ),
              RestoreViewState(
                phase: RestorePhase.confirmingPrimary,
                account: _accountA,
                localLedger: populated,
                cloudPreview: preview,
              ),
              RestoreViewState(
                phase: RestorePhase.confirmingReplacement,
                account: _accountA,
                localLedger: populated,
                cloudPreview: preview,
                primaryConfirmed: true,
              ),
              RestoreViewState(
                phase: RestorePhase.interruptedRecovery,
                account: _accountA,
                localLedger: populated,
                cloudPreview: preview,
                pendingTransfer: PendingRestoreTransfer(
                  requestId: 'req-1',
                  ownerUserId: _accountA.userId,
                  targetDeviceId: populated.deviceId,
                  expectedVersion: preview.version,
                  expectedActiveDeviceId: preview.activeDeviceId,
                  confirmedAt: preview.confirmedAt,
                  requiresTakeover: true,
                  requiresReplacement: true,
                  consentedLocalRevisionStamp: populated.revisionStamp,
                  stage: RestoreTransferStage.takeoverConfirmed,
                  cloudPreview: preview,
                ),
              ),
              RestoreViewState(
                phase: RestorePhase.missingBackup,
                account: _accountA,
                localLedger: populated,
              ),
              RestoreViewState(
                phase: RestorePhase.offline,
                account: _accountA,
                localLedger: populated,
              ),
              RestoreViewState(
                phase: RestorePhase.accountMismatch,
                account: _accountA,
                localLedger: populated,
              ),
              RestoreViewState(
                phase: RestorePhase.completed,
                account: _accountA,
                localLedger: populated.copyWith(pendingChangesCount: 0),
                cloudPreview: preview,
                authorityTransferred: true,
              ),
            ];

            for (final restoreState in statesToVerify) {
              await _pumpRestore(
                tester,
                RestoreScreen(state: restoreState),
                locale: locale,
                themeMode: themeMode,
                size: const Size(320, 640),
              );
              expect(tester.takeException(), isNull);
            }
          },
        );
      }
    }
  });
}
