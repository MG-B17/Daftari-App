import 'dart:async';
import 'dart:ui' show PlatformDispatcher, Tristate;

import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/extensions/string_extensions.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/core/routing/app_routes.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/core/services/loacl_storage/local_storage_service.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/theme/theme_controller/theme_switcher_cubit.dart';
import 'package:daftariapp/core/utils/app_date_utils.dart';
import 'package:daftariapp/core/widgets/app_error_dialog.dart';
import 'package:daftariapp/core/widgets/app_success_dialog.dart';
import 'package:daftariapp/core/widgets/daftari_loading.dart';
import 'package:daftariapp/features/auth/session/domain/entities/auth_user.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'package:daftariapp/features/auth/session/presentation/cubit/auth_session_state.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_schedule.dart';
import 'package:daftariapp/features/backup/domain/repositories/backup_scheduler.dart';
import 'package:daftariapp/features/backup/domain/usecases/run_backup_usecase.dart';
import 'package:daftariapp/features/backup/domain/usecases/update_backup_schedule_usecase.dart';
import 'package:daftariapp/features/backup/presentation/cubit/backup_cubit.dart';
import 'package:daftariapp/features/backup/presentation/models/backup_view_state.dart';
import 'package:daftariapp/features/backup/presentation/screens/backup_screen.dart';
import 'package:daftariapp/features/backup/presentation/widgets/backup_settings_section.dart';
import 'package:daftariapp/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:daftariapp/features/settings/domain/usecases/change_language_usecase.dart';
import 'package:daftariapp/features/settings/domain/usecases/get_settings_usecase.dart';
import 'package:daftariapp/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:daftariapp/features/settings/presentation/screens/settings_screen.dart';
import 'package:daftariapp/features/settings/presentation/widgets/language_picker_sheet.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:daftariapp/main.dart' show startDaftariApp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../dashboard_test_setup.dart';
import '../../security_test_setup.dart';

import '../auth/auth_test_fakes.dart';
import 'domain/backup_domain_fakes.dart';

final _now = DateTime.now();

const _signedInUser = AuthUser(
  id: 'user-a',
  email: 'shop@example.com',
  shopName: 'Al-Amana Grocery',
  emailVerified: true,
);

BackupViewState _state(BackupStatus status, {bool withConfirmed = true}) =>
    switch (status) {
      BackupStatus.neverBackedUp => const BackupViewState(
        status: BackupStatus.neverBackedUp,
        pendingChanges: 5,
        accountEmail: 'shop@example.com',
        accountShopName: 'Al-Amana Grocery',
      ),
      BackupStatus.pending => BackupViewState(
        status: BackupStatus.pending,
        pendingChanges: 3,
        lastConfirmedAt: withConfirmed ? _now : null,
        accountEmail: 'shop@example.com',
        accountShopName: 'Al-Amana Grocery',
      ),
      BackupStatus.running => BackupViewState(
        status: BackupStatus.running,
        pendingChanges: 3,
        lastConfirmedAt: withConfirmed ? _now : null,
        accountEmail: 'shop@example.com',
        accountShopName: 'Al-Amana Grocery',
      ),
      BackupStatus.failed => BackupViewState(
        status: BackupStatus.failed,
        pendingChanges: 2,
        lastConfirmedAt: withConfirmed ? _now : null,
        accountEmail: 'shop@example.com',
        accountShopName: 'Al-Amana Grocery',
      ),
      BackupStatus.upToDate => BackupViewState(
        status: BackupStatus.upToDate,
        pendingChanges: 0,
        schedule: BackupSchedule.weekly,
        lastConfirmedAt: withConfirmed ? _now : null,
        accountEmail: 'shop@example.com',
        accountShopName: 'Al-Amana Grocery',
      ),
    };

Future<void> _pump(
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

Finder _backupNowButton() => find.descendant(
  of: find.byKey(const ValueKey('backup-now')),
  matching: find.byType(FilledButton),
);

String _lastConfirmed(BuildContext context, BackupViewState state) {
  final at = state.lastConfirmedAt;
  if (at == null) return context.l10n.backupNeverConfirmed;
  final locale = Localizations.localeOf(context).languageCode;
  return context.l10n
      .backupLastConfirmed(
        AppDateUtils.relativeDay(at, locale: locale),
        AppDateUtils.formatTime(at, locale: locale),
      )
      .toWesternDigits;
}

String _statusLabel(BuildContext context, BackupStatus status) =>
    switch (status) {
      BackupStatus.neverBackedUp => context.l10n.backupStatusNeverBackedUp,
      BackupStatus.pending => context.l10n.backupStatusPending,
      BackupStatus.running => context.l10n.backupStatusRunning,
      BackupStatus.failed => context.l10n.backupStatusFailed,
      BackupStatus.upToDate => context.l10n.backupStatusUpToDate,
    };

void main() {
  setUpAll(AppDateUtils.initialize);

  test('manual backup and preview defaults enforce eligibility rules', () {
    expect(_state(BackupStatus.neverBackedUp).canBackUpNow, isTrue);
    expect(_state(BackupStatus.pending).canBackUpNow, isTrue);
    expect(_state(BackupStatus.failed).canBackUpNow, isTrue);
    expect(_state(BackupStatus.running).canBackUpNow, isFalse);
    expect(_state(BackupStatus.upToDate).canBackUpNow, isFalse);
    expect(
      const BackupViewState(
        status: BackupStatus.neverBackedUp,
        pendingChanges: 0,
      ).canBackUpNow,
      isFalse,
    );

    final preview = BackupViewState.preview();
    expect(preview.status, BackupStatus.neverBackedUp);
    expect(preview.pendingChanges, 0);
    expect(preview.schedule, isNull);
    expect(preview.lastConfirmedAt, isNull);
    expect(preview.accountEmail, isNull);
    expect(preview.accountShopName, isNull);
    expect(preview.isPreview, isTrue);
    expect(preview.canBackUpNow, isFalse);
  });

  for (final locale in ['ar', 'en']) {
    testWidgets(
      'fresh signed-out default shows signed-out empty preview in $locale',
      (tester) async {
        final backend = FakeAuthBackend();
        final sessionCubit = await createInitializedSessionCubit(backend);
        addTearDown(() async {
          await sessionCubit.close();
          await backend.dispose();
        });

        await _pump(
          tester,
          const Scaffold(
            body: SingleChildScrollView(child: BackupSettingsSection()),
          ),
          locale: locale,
          providers: [
            BlocProvider<AuthSessionCubit>.value(value: sessionCubit),
          ],
        );
        var l10n = tester.element(find.byType(BackupSettingsSection)).l10n;
        expect(
          find.byKey(const ValueKey('backup-preview-banner')),
          findsOneWidget,
        );
        expect(find.text(l10n.backupPreviewBanner), findsOneWidget);
        expect(find.text(l10n.backupStatusNeverBackedUp), findsOneWidget);
        expect(find.text(l10n.backupNeverConfirmed), findsOneWidget);
        expect(find.text(l10n.backupPendingChanges(0)), findsOneWidget);
        expect(
          tester.widget<FilledButton>(_backupNowButton()).onPressed,
          isNull,
        );

        await _pump(
          tester,
          const BackupScreen(),
          locale: locale,
          providers: [
            BlocProvider<AuthSessionCubit>.value(value: sessionCubit),
          ],
        );
        l10n = tester.element(find.byType(BackupScreen)).l10n;
        expect(
          find.byKey(const ValueKey('backup-preview-banner')),
          findsOneWidget,
        );
        expect(find.text(l10n.backupPreviewBanner), findsOneWidget);
        expect(find.text(l10n.backupStatusNeverBackedUp), findsOneWidget);
        expect(find.text(l10n.backupNeverConfirmed), findsOneWidget);
        expect(find.text(l10n.backupPendingChanges(0)), findsOneWidget);
        expect(find.text(l10n.backupAccountSignedOutTitle), findsOneWidget);
        expect(find.text(l10n.backupAccountSignedOutSubtitle), findsOneWidget);
        expect(find.text(l10n.backupActiveAccount), findsNothing);
        expect(find.textContaining('mohamed.store@gmail.com'), findsNothing);
        expect(backend.linkedUserId, isNull);
        expect(
          tester.widget<FilledButton>(_backupNowButton()).onPressed,
          isNull,
        );
      },
    );

    testWidgets(
      'signing out of linked ledger reports signed out and preserves owner in $locale',
      (tester) async {
        final backend = FakeAuthBackend(
          currentUser: _signedInUser,
          linkedUserId: _signedInUser.id,
        );
        final sessionCubit = await createInitializedSessionCubit(backend);
        addTearDown(() async {
          await sessionCubit.close();
          await backend.dispose();
        });

        await sessionCubit.signOut();

        await _pump(
          tester,
          const BackupScreen(),
          locale: locale,
          providers: [
            BlocProvider<AuthSessionCubit>.value(value: sessionCubit),
          ],
        );
        final l10n = tester.element(find.byType(BackupScreen)).l10n;
        expect(find.text(l10n.backupAccountSignedOutTitle), findsOneWidget);
        expect(find.text(l10n.backupAccountSignedOutSubtitle), findsOneWidget);
        expect(find.text('Al-Amana Grocery'), findsNothing);
        expect(find.text('shop@example.com'), findsNothing);
        expect(find.text(l10n.backupActiveAccount), findsNothing);
        expect(backend.linkedUserId, _signedInUser.id);
      },
    );
  }

  testWidgets(
    'signed-in default preview reflects linked account and preview notice',
    (tester) async {
      final backend = FakeAuthBackend(
        currentUser: _signedInUser,
        linkedUserId: _signedInUser.id,
      );
      final sessionCubit = await createInitializedSessionCubit(backend);
      addTearDown(() async {
        await sessionCubit.close();
        await backend.dispose();
      });

      await _pump(
        tester,
        const BackupScreen(),
        locale: 'en',
        providers: [BlocProvider<AuthSessionCubit>.value(value: sessionCubit)],
      );
      final l10n = tester.element(find.byType(BackupScreen)).l10n;
      expect(
        find.byKey(const ValueKey('backup-preview-banner')),
        findsOneWidget,
      );
      expect(find.text(l10n.backupNeverConfirmed), findsOneWidget);
      expect(find.text('Al-Amana Grocery'), findsOneWidget);
      expect(find.text('shop@example.com'), findsOneWidget);
      expect(find.text(l10n.backupActiveAccount), findsOneWidget);
    },
  );

  for (final locale in ['ar', 'en']) {
    for (final status in BackupStatus.values) {
      testWidgets('settings section renders ${status.name} in $locale', (
        tester,
      ) async {
        final state = _state(status);
        await _pump(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: BackupSettingsSection(state: state),
            ),
          ),
          locale: locale,
        );
        final context = tester.element(find.byType(BackupSettingsSection));
        final l10n = context.l10n;

        expect(
          Directionality.of(context),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(find.text(l10n.backupSectionTitle), findsOneWidget);
        expect(find.text(l10n.backupSyncStatusTitle), findsOneWidget);
        expect(
          find.byKey(ValueKey('backup-status-${status.name}')),
          findsOneWidget,
        );
        expect(find.text(_statusLabel(context, status)), findsOneWidget);
        expect(find.text(_lastConfirmed(context, state)), findsOneWidget);
        expect(
          find.text(l10n.backupPendingChanges(state.pendingChanges)),
          findsOneWidget,
        );
        expect(
          find.text(l10n.backupFailedHint),
          status == BackupStatus.failed ? findsOneWidget : findsNothing,
        );
        expect(find.text(l10n.backupFailedFirstHint), findsNothing);
        expect(
          find.byType(LinearProgressIndicator),
          status == BackupStatus.running ? findsOneWidget : findsNothing,
        );
        expect(find.text(l10n.backupNowTitle), findsOneWidget);
        expect(find.text(l10n.backupManageTitle), findsOneWidget);
        expect(
          tester.widget<FilledButton>(_backupNowButton()).onPressed != null,
          state.canBackUpNow,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('backup screen renders ${status.name} in $locale', (
        tester,
      ) async {
        final state = _state(status);
        await _pump(tester, BackupScreen(state: state), locale: locale);
        final context = tester.element(find.byType(BackupScreen));
        final l10n = context.l10n;

        expect(
          Directionality.of(context),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(l10n.backupScreenTitle),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('backup-status-${status.name}')),
          findsOneWidget,
        );
        expect(find.text(_lastConfirmed(context, state)), findsOneWidget);
        expect(
          find.text(l10n.backupPendingChanges(state.pendingChanges)),
          findsOneWidget,
        );
        expect(find.text('Al-Amana Grocery'), findsOneWidget);
        expect(find.text('shop@example.com'), findsOneWidget);
        expect(find.text(l10n.backupActiveAccount), findsOneWidget);
        expect(
          find.text(l10n.backupFailedHint),
          status == BackupStatus.failed ? findsOneWidget : findsNothing,
        );
        expect(find.text(l10n.backupFailedFirstHint), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.byType(DaftariLoading),
          status == BackupStatus.running ? findsWidgets : findsNothing,
        );
        expect(
          tester.widget<FilledButton>(_backupNowButton()).onPressed != null,
          state.canBackUpNow,
        );
        expect(find.text(l10n.backupScheduleTitle), findsOneWidget);
        expect(find.text(l10n.backupScheduleDaily), findsOneWidget);
        expect(find.text(l10n.backupScheduleWeekly), findsOneWidget);
        expect(find.text(l10n.backupScheduleMonthly), findsOneWidget);
        expect(find.text(l10n.backupScheduleCaption), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'first-attempt failure avoids mentioning previous backup in $locale',
      (tester) async {
        final firstFailure = _state(BackupStatus.failed, withConfirmed: false);

        await _pump(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: BackupSettingsSection(state: firstFailure),
            ),
          ),
          locale: locale,
        );
        var l10n = tester.element(find.byType(BackupSettingsSection)).l10n;
        expect(find.text(l10n.backupNeverConfirmed), findsOneWidget);
        expect(find.text(l10n.backupFailedFirstHint), findsOneWidget);
        expect(find.text(l10n.backupFailedHint), findsNothing);

        await _pump(tester, BackupScreen(state: firstFailure), locale: locale);
        l10n = tester.element(find.byType(BackupScreen)).l10n;
        expect(find.text(l10n.backupNeverConfirmed), findsOneWidget);
        expect(find.text(l10n.backupFailedFirstHint), findsOneWidget);
        expect(find.text(l10n.backupFailedHint), findsNothing);
      },
    );
  }

  testWidgets(
    'tapping schedule options updates the mock selection immediately',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        Color? cardColor(BackupSchedule schedule) => tester
            .widget<Material>(
              find
                  .ancestor(
                    of: find.byKey(
                      ValueKey('backup-schedule-${schedule.name}'),
                    ),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color;

        Tristate isSelected(BackupSchedule schedule) => tester
            .getSemantics(
              find.byKey(ValueKey('backup-schedule-${schedule.name}')),
            )
            .flagsCollection
            .isSelected;

        await _pump(tester, BackupScreen(state: _state(BackupStatus.pending)));
        final colors = tester.element(find.byType(BackupScreen)).colorScheme;
        for (final schedule in BackupSchedule.values) {
          expect(isSelected(schedule), Tristate.isFalse);
          expect(cardColor(schedule), isNot(colors.primary));
        }

        await tester.tap(find.byKey(const ValueKey('backup-schedule-weekly')));
        await tester.pump();
        expect(isSelected(BackupSchedule.weekly), Tristate.isTrue);
        expect(cardColor(BackupSchedule.weekly), colors.primary);
        expect(isSelected(BackupSchedule.daily), Tristate.isFalse);
        expect(cardColor(BackupSchedule.daily), isNot(colors.primary));
        expect(isSelected(BackupSchedule.monthly), Tristate.isFalse);
        expect(cardColor(BackupSchedule.monthly), isNot(colors.primary));

        await tester.tap(find.byKey(const ValueKey('backup-schedule-monthly')));
        await tester.pump();
        expect(isSelected(BackupSchedule.monthly), Tristate.isTrue);
        expect(cardColor(BackupSchedule.monthly), colors.primary);
        expect(isSelected(BackupSchedule.weekly), Tristate.isFalse);
        expect(cardColor(BackupSchedule.weekly), isNot(colors.primary));
        expect(isSelected(BackupSchedule.daily), Tristate.isFalse);
        expect(cardColor(BackupSchedule.daily), isNot(colors.primary));
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('mock manual backup shows the preview notice', (tester) async {
    await _pump(
      tester,
      BackupScreen(state: _state(BackupStatus.pending)),
      locale: 'en',
    );
    final l10n = tester.element(find.byType(BackupScreen)).l10n;

    await tester.tap(find.byKey(const ValueKey('backup-now')));
    await tester.pump();
    expect(find.text(l10n.backupMockNotice), findsOneWidget);
  });

  testWidgets('backup UI fits a narrow RTL screen with enlarged text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final status in BackupStatus.values) {
      await _pump(
        tester,
        BackupScreen(state: _state(status)),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: BackupSettingsSection(state: _state(status)),
          ),
        ),
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('backup UI renders in dark theme', (tester) async {
    for (final locale in ['ar', 'en']) {
      await _pump(
        tester,
        BackupScreen(state: _state(BackupStatus.failed)),
        locale: locale,
        themeMode: ThemeMode.dark,
      );
      expect(
        Theme.of(tester.element(find.byType(BackupScreen))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'P12-25: scheduler PlatformException before first frame completes cleanly and keeps UI usable',
    (tester) async {
      final dateService = FakeDateService(DateTime.utc(2026, 11, 24, 10));
      final authController = StreamController<AuthSessionState>.broadcast();
      addTearDown(authController.close);
      const authState = AuthSessionState(
        initialized: true,
        isConfigured: true,
        status: AuthStatus.authenticated,
        user: _signedInUser,
      );
      final localStore = FakeBackupLocalStore(
        scheduleState: BackupScheduleState(
          schedule: BackupSchedule.daily,
          lastConfirmedAt: DateTime.utc(2026, 11, 24, 9),
          nextDueAt: DateTime.utc(2026, 11, 25, 9),
        ),
      );
      final publisher = FakeBackupCloudPublisher(serverTime: dateService.now());
      final runLock = InMemoryBackupRunLock();
      final syncStarted = Completer<void>();
      final releaseSync = Completer<void>();
      final failingScheduler = _ControlledFailingScheduler(
        onSync: () {
          if (!syncStarted.isCompleted) syncStarted.complete();
          return releaseSync.future;
        },
      );
      final cubit = BackupCubit(
        runBackup: RunBackupUseCase(
          localStore: localStore,
          cloudPublisher: publisher,
          runLock: runLock,
          dateService: dateService,
        ),
        updateSchedule: UpdateBackupScheduleUseCase(
          localStore: localStore,
          dateService: dateService,
        ),
        localStore: localStore,
        scheduler: failingScheduler,
        runLock: runLock,
        dateService: dateService,
        readAuthState: () => authState,
        authStateStream: authController.stream,
        connectivityStream: const Stream<bool>.empty(),
      );

      addTearDown(cubit.close);

      final initFuture = cubit.initialize();

      await _pump(
        tester,
        const BackupScreen(),
        providers: [BlocProvider<BackupCubit>.value(value: cubit)],
      );

      // First screen is visible while native scheduling is still pending.
      expect(find.byType(BackupScreen), findsOneWidget);
      expect(syncStarted.isCompleted, isTrue);
      expect(failingScheduler.syncCalls, 1);

      // Explicitly trigger the scheduler PlatformException and await initialization.
      releaseSync.completeError(
        PlatformException(code: 'scheduler_unavailable'),
      );
      await tester.pump();
      await initFuture;
      await tester.pump();

      expect(failingScheduler.syncCalls, 1);
      expect(find.byType(BackupScreen), findsOneWidget);
      expect(cubit.state.schedule, BackupSchedule.daily);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'P12-22: startDaftariApp mounts first screen without waiting on pending backup scheduling',
    (tester) async {
      final dateService = FakeDateService(DateTime.utc(2026, 11, 24, 10));
      final authController = StreamController<AuthSessionState>.broadcast();
      addTearDown(authController.close);
      const authState = AuthSessionState(
        initialized: true,
        isConfigured: true,
        status: AuthStatus.authenticated,
        user: _signedInUser,
      );
      final localStore = FakeBackupLocalStore(
        scheduleState: BackupScheduleState(
          schedule: BackupSchedule.daily,
          lastConfirmedAt: DateTime.utc(2026, 11, 24, 9),
          nextDueAt: DateTime.utc(2026, 11, 25, 9),
        ),
      );
      final publisher = FakeBackupCloudPublisher(serverTime: dateService.now());
      final runLock = InMemoryBackupRunLock();
      final syncStarted = Completer<void>();
      final releaseSync = Completer<void>();
      final stalledScheduler = _ControlledFailingScheduler(
        onSync: () {
          if (!syncStarted.isCompleted) syncStarted.complete();
          return releaseSync.future;
        },
      );
      final cubit = BackupCubit(
        runBackup: RunBackupUseCase(
          localStore: localStore,
          cloudPublisher: publisher,
          runLock: runLock,
          dateService: dateService,
        ),
        updateSchedule: UpdateBackupScheduleUseCase(
          localStore: localStore,
          dateService: dateService,
        ),
        localStore: localStore,
        scheduler: stalledScheduler,
        runLock: runLock,
        dateService: dateService,
        readAuthState: () => authState,
        authStateStream: authController.stream,
        connectivityStream: const Stream<bool>.empty(),
      );
      addTearDown(cubit.close);

      final previousFlutterError = FlutterError.onError;
      final previousPlatformError = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = previousFlutterError;
        PlatformDispatcher.instance.onError = previousPlatformError;
      });

      Widget? mountedApp;
      startDaftariApp(
        logger: AppLogger(output: (_) {}, enableCrashReporting: false),
        backupCubit: cubit,
        app: const BackupScreen(),
        runAppCallback: (widget) {
          mountedApp = widget;
        },
      );

      // startDaftariApp returns synchronously and provides the root widget before
      // backup scheduling completes.
      expect(mountedApp, isNotNull);

      await _pump(
        tester,
        mountedApp!,
        providers: [BlocProvider<BackupCubit>.value(value: cubit)],
      );

      expect(find.byType(BackupScreen), findsOneWidget);
      expect(syncStarted.isCompleted, isTrue);
      expect(releaseSync.isCompleted, isFalse);

      releaseSync.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  group(
    'Task 10 — manual backup feedback, silent schedule, and slide route',
    () {
      ({
        BackupCubit cubit,
        FakeBackupLocalStore localStore,
        FakeBackupCloudPublisher publisher,
        InMemoryBackupRunLock runLock,
        FakeDateService dateService,
      })
      createLiveBackup({
        bool withPendingCustomer = true,
        Future<bool> Function()? checkRemoteRunLocked,
      }) {
        final dateService = FakeDateService(DateTime.utc(2026, 11, 24, 10));
        final authController = StreamController<AuthSessionState>.broadcast();
        addTearDown(authController.close);
        const authState = AuthSessionState(
          initialized: true,
          isConfigured: true,
          status: AuthStatus.authenticated,
          user: _signedInUser,
        );
        final runLock = InMemoryBackupRunLock();
        final localStore = FakeBackupLocalStore(runLockForRunningFlag: runLock);
        if (withPendingCustomer) {
          localStore.putCustomer(testCustomer());
        }
        final publisher = FakeBackupCloudPublisher(
          serverTime: dateService.now(),
        );
        final cubit = BackupCubit(
          runBackup: RunBackupUseCase(
            localStore: localStore,
            cloudPublisher: publisher,
            runLock: runLock,
            dateService: dateService,
          ),
          updateSchedule: UpdateBackupScheduleUseCase(
            localStore: localStore,
            dateService: dateService,
          ),
          localStore: localStore,
          scheduler: _NoOpScheduler(),
          runLock: runLock,
          dateService: dateService,
          readAuthState: () => authState,
          authStateStream: authController.stream,
          connectivityStream: const Stream<bool>.empty(),
          checkRemoteRunLocked: checkRemoteRunLocked,
        );
        addTearDown(cubit.close);
        return (
          cubit: cubit,
          localStore: localStore,
          publisher: publisher,
          runLock: runLock,
          dateService: dateService,
        );
      }

      for (final locale in ['ar', 'en']) {
        testWidgets(
          'manual backup confirmed shows shared success dialog once in $locale',
          (tester) async {
            final live = createLiveBackup();
            await live.cubit.initialize();

            await _pump(
              tester,
              const BackupScreen(),
              locale: locale,
              providers: [BlocProvider<BackupCubit>.value(value: live.cubit)],
            );
            final l10n = tester.element(find.byType(BackupScreen)).l10n;

            await tester.tap(find.byKey(const ValueKey('backup-now')));
            await tester.pump();
            await tester.pump();

            expect(live.publisher.publishedBatches.length, 1);
            expect(find.byType(AppSuccessDialog), findsOneWidget);
            expect(find.text(l10n.backupManualSuccessTitle), findsOneWidget);
            expect(find.text(l10n.backupManualSuccessMessage), findsOneWidget);
            expect(find.byType(AppErrorDialog), findsNothing);

            await tester.tap(find.text(l10n.ok));
            await tester.pump();
            expect(find.byType(AppSuccessDialog), findsNothing);

            // Subsequent refresh does not replay the consumed dialog.
            await live.cubit.refresh();
            await tester.pump();
            expect(find.byType(AppSuccessDialog), findsNothing);
          },
        );
      }

      testWidgets(
        'manual backup with nothing new to upload shows accurate nothing-to-upload dialog',
        (tester) async {
          final live = createLiveBackup();
          live.localStore.forceEmptyCaptureOnce = true;
          await live.cubit.initialize();

          await _pump(
            tester,
            const BackupScreen(),
            locale: 'en',
            providers: [BlocProvider<BackupCubit>.value(value: live.cubit)],
          );
          final l10n = tester.element(find.byType(BackupScreen)).l10n;

          await tester.tap(find.byKey(const ValueKey('backup-now')));
          await tester.pump();
          await tester.pump();

          expect(live.publisher.publishedBatches, isEmpty);
          expect(
            live.cubit.state.manualFeedback,
            BackupManualFeedback.nothingToUpload,
          );
          expect(find.byType(AppSuccessDialog), findsOneWidget);
          expect(
            find.text(l10n.backupManualNothingToUploadTitle),
            findsOneWidget,
          );
          expect(
            find.text(l10n.backupManualNothingToUploadMessage),
            findsOneWidget,
          );
          expect(find.text(l10n.backupManualSuccessTitle), findsNothing);
        },
      );

      testWidgets(
        'manual backup failures report accurate error dialogs for network, first failure, subsequent failure, and inactive device',
        (tester) async {
          final live = createLiveBackup();
          await live.cubit.initialize();

          await _pump(
            tester,
            const BackupScreen(),
            locale: 'en',
            providers: [BlocProvider<BackupCubit>.value(value: live.cubit)],
          );
          final l10n = tester.element(find.byType(BackupScreen)).l10n;

          // 1. Network failure.
          live.publisher.nextFailure = const AppFailure(AppErrorCode.network);
          await tester.tap(find.byKey(const ValueKey('backup-now')));
          await tester.pump();
          await tester.pump();
          expect(find.byType(AppErrorDialog), findsOneWidget);
          expect(find.text(l10n.backupManualOfflineMessage), findsOneWidget);
          await tester.tap(find.text(l10n.ok));
          await tester.pump();

          // 2. First-attempt unexpected failure (never confirmed before).
          live.publisher.nextFailure = const AppFailure(
            AppErrorCode.unexpected,
          );
          await tester.tap(find.byKey(const ValueKey('backup-now')));
          await tester.pump();
          await tester.pump();
          expect(find.byType(AppErrorDialog), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(AppErrorDialog),
              matching: find.text(l10n.backupFailedFirstHint),
            ),
            findsOneWidget,
          );
          await tester.tap(find.text(l10n.ok));
          await tester.pump();

          // 3. Confirmed backup followed by later failure preserves previous backup hint.
          live.publisher.nextFailure = null;
          await tester.tap(find.byKey(const ValueKey('backup-now')));
          await tester.pump();
          await tester.pump();
          expect(find.byType(AppSuccessDialog), findsOneWidget);
          await tester.tap(find.text(l10n.ok));
          await tester.pump();

          live.localStore.putCustomer(testCustomer(id: 'cust-2', name: 'Mona'));
          await live.cubit.refresh();
          await tester.pump();
          live.publisher.nextFailure = const AppFailure(
            AppErrorCode.unexpected,
          );
          await tester.tap(find.byKey(const ValueKey('backup-now')));
          await tester.pump();
          await tester.pump();
          expect(find.byType(AppErrorDialog), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(AppErrorDialog),
              matching: find.text(l10n.backupFailedHint),
            ),
            findsOneWidget,
          );
          await tester.tap(find.text(l10n.ok));
          await tester.pump();

          // 4. Server rejects as inactive device.
          live.publisher.nextFailure = null;
          live.publisher.rejectAsInactiveDevice = true;
          await tester.tap(find.byKey(const ValueKey('backup-now')));
          await tester.pump();
          await tester.pump();
          expect(find.byType(AppErrorDialog), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(AppErrorDialog),
              matching: find.text(l10n.backupInactiveDeviceHint),
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'rapid duplicate manual backup trigger executes once and shows one dialog',
        (tester) async {
          final live = createLiveBackup();
          final uploadStarted = Completer<void>();
          final releaseUpload = Completer<void>();
          live.publisher.onPublishStarted = (_) async {
            if (!uploadStarted.isCompleted) uploadStarted.complete();
            await releaseUpload.future;
          };
          await live.cubit.initialize();

          await _pump(
            tester,
            const BackupScreen(),
            locale: 'en',
            providers: [BlocProvider<BackupCubit>.value(value: live.cubit)],
          );

          await tester.tap(find.byKey(const ValueKey('backup-now')));
          await tester.pump();
          await uploadStarted.future;
          await tester.pump();

          // Button is disabled while pending and direct duplicate call is ignored.
          expect(
            tester.widget<FilledButton>(_backupNowButton()).onPressed,
            isNull,
          );
          expect(find.byType(DaftariLoading), findsWidgets);
          await live.cubit.backUpNow();

          releaseUpload.complete();
          await tester.pump();
          await tester.pump();

          expect(live.publisher.publishedBatches.length, 1);
          expect(live.cubit.state.manualFeedbackId, 1);
          expect(find.byType(AppSuccessDialog), findsOneWidget);
        },
      );

      testWidgets(
        'scheduled backup runs stay silent for confirmed, skipped, and failed outcomes',
        (tester) async {
          final live = createLiveBackup();
          live.localStore.scheduleState = BackupScheduleState(
            schedule: BackupSchedule.daily,
            lastConfirmedAt: DateTime.utc(2026, 11, 22, 10),
            nextDueAt: DateTime.utc(2026, 11, 23, 10),
          );

          await _pump(
            tester,
            const BackupScreen(),
            locale: 'en',
            providers: [BlocProvider<BackupCubit>.value(value: live.cubit)],
          );

          // 1. Scheduled confirmed backup stays silent.
          await live.cubit.runScheduledIfDue();
          await tester.pump();
          expect(live.publisher.publishedBatches.length, 1);
          expect(live.cubit.state.manualFeedback, BackupManualFeedback.none);
          expect(live.cubit.state.manualFeedbackId, 0);
          expect(find.byType(AppSuccessDialog), findsNothing);
          expect(find.byType(AppErrorDialog), findsNothing);

          // 2. Scheduled overdue run with nothing to upload stays silent.
          live.dateService.current = DateTime.utc(2026, 11, 26, 10);
          await live.cubit.runScheduledIfDue();
          await tester.pump();
          expect(live.cubit.state.manualFeedbackId, 0);
          expect(find.byType(AppSuccessDialog), findsNothing);
          expect(find.byType(AppErrorDialog), findsNothing);

          // 3. Scheduled failure stays silent.
          live.localStore.putCustomer(testCustomer(id: 'cust-2', name: 'Nour'));
          live.dateService.current = DateTime.utc(2026, 11, 28, 10);
          live.publisher.nextFailure = const AppFailure(AppErrorCode.network);
          await live.cubit.runScheduledIfDue();
          await tester.pump();
          expect(live.cubit.state.status, BackupStatus.failed);
          expect(live.cubit.state.manualFeedbackId, 0);
          expect(find.byType(AppErrorDialog), findsNothing);
        },
      );

      testWidgets(
        'Settings to Backup and Back uses existing slide transition, respects reduced motion, and delivers manual feedback once',
        (tester) async {
          await setupDashboardTests();
          addTearDown(sl.reset);
          SharedPreferences.setMockInitialValues({
            'localeCode': 'ar',
            'themeMode': ThemeMode.light.name,
            'onboardingCompleted': true,
          });
          final storage = LocalStorageService(
            await SharedPreferences.getInstance(),
          );
          final errorHandler = ErrorHandler(
            AppLogger(output: (_) {}, enableCrashReporting: false),
          );
          final settingsCubit = SettingsCubit(
            GetSettingsUseCase(SettingsRepositoryImpl(storage)),
            ChangeLanguageUseCase(SettingsRepositoryImpl(storage)),
            errorHandler,
          );
          final themeSwitcher = ThemeSwitcherCubit(storage, errorHandler);
          final appLock = await testAppLock();
          final live = createLiveBackup();
          await live.cubit.initialize();
          final router = AppRouter.create(
            localStorage: storage,
            appLock: appLock,
          );
          addTearDown(() async {
            router.dispose();
            await settingsCubit.close();
            await themeSwitcher.close();
            await appLock.close();
          });

          tester.view.physicalSize = const Size(400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            DaftariApp(
              router: router,
              settingsCubit: settingsCubit,
              themeSwitcherCubit: themeSwitcher,
              appLockCubit: appLock,
              backupCubit: live.cubit,
            ),
          );
          await tester.pump();
          router.go(AppRoutes.settings);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(SettingsScreen), findsOneWidget);

          // Tap Manage backup -> pushes BackupScreen with SlideTransition.
          final manageTile = find.byKey(const ValueKey('backup-manage-tile'));
          await tester.ensureVisible(manageTile);
          await tester.tap(manageTile);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(
            find.ancestor(
              of: find.byType(BackupScreen),
              matching: find.byType(SlideTransition),
            ),
            findsOneWidget,
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(BackupScreen), findsOneWidget);

          // Manual backup on BackupScreen shows dialog once (Settings underneath ignores it).
          final l10n = tester.element(find.byType(BackupScreen)).l10n;
          await tester.tap(
            find.descendant(
              of: find.byType(BackupScreen),
              matching: find.byKey(const ValueKey('backup-now')),
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(find.byType(AppSuccessDialog), findsOneWidget);
          await tester.tap(find.text(l10n.ok));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(AppSuccessDialog), findsNothing);

          // Navigate Back while a new manual backup is pending -> Settings shows result once.
          live.localStore.putCustomer(
            testCustomer(id: 'cust-2', name: 'Salma'),
          );
          await live.cubit.refresh();
          await tester.pump();
          final uploadStarted = Completer<void>();
          final releaseUpload = Completer<void>();
          live.publisher.onPublishStarted = (_) async {
            if (!uploadStarted.isCompleted) uploadStarted.complete();
            await releaseUpload.future;
          };
          await tester.tap(
            find.descendant(
              of: find.byType(BackupScreen),
              matching: find.byKey(const ValueKey('backup-now')),
            ),
          );
          await tester.pump();
          await uploadStarted.future;

          await tester.tap(find.byType(BackButton));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(BackupScreen), findsNothing);
          expect(find.byType(SettingsScreen), findsOneWidget);

          releaseUpload.complete();
          await tester.pump();
          await tester.pump();
          expect(find.byType(AppSuccessDialog), findsOneWidget);
          await tester.tap(find.text(l10n.ok));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(AppSuccessDialog), findsNothing);

          // Reduced motion skips SlideTransition on Settings -> Backup.
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures.allOn;
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          await tester.pump();
          await tester.ensureVisible(manageTile);
          await tester.tap(manageTile);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            find.ancestor(
              of: find.byType(BackupScreen),
              matching: find.byType(SlideTransition),
            ),
            findsNothing,
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(BackupScreen), findsOneWidget);

          await tester.pumpWidget(const SizedBox());
        },
      );

      test('P15-05: rapid overlapping manual calls during pending remote-lock check execute once with uninterrupted busy state', () async {
        Completer<bool>? remoteLockCheck;
        var remoteLockCalls = 0;
        final live = createLiveBackup(
          checkRemoteRunLocked: () {
            remoteLockCalls++;
            final pending = remoteLockCheck;
            if (pending != null) return pending.future;
            return Future<bool>.value(false);
          },
        );
        await live.cubit.initialize();

        final lockCheck = Completer<bool>();
        remoteLockCheck = lockCheck;
        final uploadStarted = Completer<void>();
        final releaseUpload = Completer<void>();
        var publishStarts = 0;
        live.publisher.onPublishStarted = (_) async {
          publishStarts++;
          if (!uploadStarted.isCompleted) uploadStarted.complete();
          await releaseUpload.future;
        };

        final states = <BackupViewState>[];
        final sub = live.cubit.stream.listen(states.add);
        addTearDown(sub.cancel);

        remoteLockCalls = 0;
        final firstRun = live.cubit.backUpNow();
        final secondRun = live.cubit.backUpNow();

        // Busy flag is reserved synchronously before remote lock returns.
        expect(live.cubit.state.isRunning, isTrue);
        expect(live.cubit.state.canBackUpNow, isFalse);
        expect(remoteLockCalls, 1);

        // Second call exits immediately without clearing busy state or publishing feedback.
        await secondRun;
        expect(live.cubit.state.isRunning, isTrue);
        expect(live.cubit.state.manualFeedback, BackupManualFeedback.none);
        expect(live.cubit.state.manualFeedbackId, 0);

        // Release lock check as unlocked; upload stays pending.
        remoteLockCheck = null;
        lockCheck.complete(false);
        await uploadStarted.future;

        expect(publishStarts, 1);
        expect(live.cubit.state.isRunning, isTrue);
        expect(live.cubit.state.canBackUpNow, isFalse);
        expect(states.every((s) => s.status == BackupStatus.running), isTrue);
        expect(
          states.any(
            (s) => s.manualFeedback == BackupManualFeedback.alreadyRunning,
          ),
          isFalse,
        );

        releaseUpload.complete();
        await firstRun;

        expect(publishStarts, 1);
        expect(live.publisher.publishedBatches.length, 1);
        expect(live.cubit.state.isRunning, isFalse);
        expect(live.cubit.state.status, BackupStatus.upToDate);
        expect(live.cubit.state.manualFeedback, BackupManualFeedback.confirmed);
        expect(live.cubit.state.manualFeedbackId, 1);
      });

      testWidgets(
        'P15-07: manual backup finishing while Settings language sheet is open delivers result once after dismissal',
        (tester) async {
          await setupDashboardTests();
          addTearDown(sl.reset);
          SharedPreferences.setMockInitialValues({
            'localeCode': 'en',
            'themeMode': ThemeMode.light.name,
            'onboardingCompleted': true,
          });
          final storage = LocalStorageService(
            await SharedPreferences.getInstance(),
          );
          final errorHandler = ErrorHandler(
            AppLogger(output: (_) {}, enableCrashReporting: false),
          );
          final settingsCubit = SettingsCubit(
            GetSettingsUseCase(SettingsRepositoryImpl(storage)),
            ChangeLanguageUseCase(SettingsRepositoryImpl(storage)),
            errorHandler,
          );
          final themeSwitcher = ThemeSwitcherCubit(storage, errorHandler);
          final appLock = await testAppLock();
          final live = createLiveBackup();
          final uploadStarted = Completer<void>();
          final releaseUpload = Completer<void>();
          live.publisher.onPublishStarted = (_) async {
            if (!uploadStarted.isCompleted) uploadStarted.complete();
            await releaseUpload.future;
          };
          await live.cubit.initialize();
          final router = AppRouter.create(
            localStorage: storage,
            appLock: appLock,
          );
          addTearDown(() async {
            router.dispose();
            await settingsCubit.close();
            await themeSwitcher.close();
            await appLock.close();
          });

          tester.view.physicalSize = const Size(400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            DaftariApp(
              router: router,
              settingsCubit: settingsCubit,
              themeSwitcherCubit: themeSwitcher,
              appLockCubit: appLock,
              backupCubit: live.cubit,
            ),
          );
          await tester.pump();
          router.go(AppRoutes.settings);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(SettingsScreen), findsOneWidget);

          // Start manual backup on Settings.
          final backupButton = find.byKey(const ValueKey('backup-now'));
          await tester.ensureVisible(backupButton);
          await tester.tap(backupButton);
          await tester.pump();
          await uploadStarted.future;
          await tester.pump();

          // Open the actual Settings language picker sheet while backup runs.
          final languageTile = find.byKey(const ValueKey('language-tile'));
          await tester.scrollUntilVisible(
            languageTile,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(languageTile);
          await tester.tap(languageTile);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(LanguagePickerSheet), findsOneWidget);

          // Finish backup while the sheet is covering Settings.
          releaseUpload.complete();
          await tester.pump();
          await tester.pump();
          expect(
            live.cubit.state.manualFeedback,
            BackupManualFeedback.confirmed,
          );
          expect(find.byType(AppSuccessDialog), findsNothing);
          expect(find.byType(AppErrorDialog), findsNothing);

          // Dismiss the language picker sheet -> Settings delivers the pending result once.
          Navigator.of(tester.element(find.byType(LanguagePickerSheet))).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(LanguagePickerSheet), findsNothing);

          final l10n = tester.element(find.byType(SettingsScreen)).l10n;
          expect(find.byType(AppSuccessDialog), findsOneWidget);
          expect(find.text(l10n.backupManualSuccessTitle), findsOneWidget);
          expect(find.text(l10n.backupManualSuccessMessage), findsOneWidget);

          await tester.tap(find.text(l10n.ok));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(AppSuccessDialog), findsNothing);

          // Subsequent refresh and Settings rebuild do not replay the result.
          await live.cubit.refresh();
          await themeSwitcher.setThemeMode(ThemeMode.dark);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byType(AppSuccessDialog), findsNothing);
          expect(find.byType(AppErrorDialog), findsNothing);

          await tester.pumpWidget(const SizedBox());
        },
      );
    },
  );
}

class _NoOpScheduler implements BackupScheduler {
  @override
  Future<void> syncSchedule(
    BackupScheduleState scheduleState, {
    required DateTime now,
  }) async {}

  @override
  Future<void> cancelScheduledBackup() async {}
}

class _ControlledFailingScheduler implements BackupScheduler {
  _ControlledFailingScheduler({required this.onSync});

  final Future<void> Function() onSync;
  int syncCalls = 0;

  @override
  Future<void> syncSchedule(
    BackupScheduleState scheduleState, {
    required DateTime now,
  }) async {
    syncCalls++;
    await onSync();
  }

  @override
  Future<void> cancelScheduledBackup() async {
    throw PlatformException(code: 'scheduler_unavailable');
  }
}
