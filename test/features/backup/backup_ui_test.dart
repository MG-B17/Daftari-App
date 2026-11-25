import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/extensions/string_extensions.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/utils/app_date_utils.dart';
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
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

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
        expect(
          find.byType(CircularProgressIndicator),
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
