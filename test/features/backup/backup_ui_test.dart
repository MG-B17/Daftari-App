import 'package:daftariapp/core/constants/app_constants.dart';
import 'package:daftariapp/core/extensions/context_extensions.dart';
import 'package:daftariapp/core/extensions/string_extensions.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/utils/app_date_utils.dart';
import 'package:daftariapp/features/backup/presentation/models/backup_view_state.dart';
import 'package:daftariapp/features/backup/presentation/screens/backup_screen.dart';
import 'package:daftariapp/features/backup/presentation/widgets/backup_settings_section.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.now();

BackupViewState _state(BackupStatus status) => switch (status) {
  BackupStatus.neverBackedUp => const BackupViewState(
    status: BackupStatus.neverBackedUp,
    pendingChanges: 5,
    accountEmail: 'shop@example.com',
    accountShopName: 'Al-Amana Grocery',
  ),
  BackupStatus.pending => BackupViewState(
    status: BackupStatus.pending,
    pendingChanges: 3,
    lastConfirmedAt: _now,
    accountEmail: 'shop@example.com',
    accountShopName: 'Al-Amana Grocery',
  ),
  BackupStatus.running => BackupViewState(
    status: BackupStatus.running,
    pendingChanges: 3,
    lastConfirmedAt: _now,
    accountEmail: 'shop@example.com',
    accountShopName: 'Al-Amana Grocery',
  ),
  BackupStatus.failed => BackupViewState(
    status: BackupStatus.failed,
    pendingChanges: 2,
    lastConfirmedAt: _now,
    accountEmail: 'shop@example.com',
    accountShopName: 'Al-Amana Grocery',
  ),
  BackupStatus.upToDate => BackupViewState(
    status: BackupStatus.upToDate,
    pendingChanges: 0,
    schedule: BackupSchedule.weekly,
    lastConfirmedAt: _now,
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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
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
    ),
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

  test('manual backup is available only with pending changes when idle', () {
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
    expect(BackupViewState.mock.status, BackupStatus.pending);
    expect(BackupViewState.mock.schedule, isNull);
  });

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
  }

  testWidgets('no schedule is selected until the user picks one', (
    tester,
  ) async {
    Color? cardColor(BackupSchedule schedule) => tester
        .widget<Material>(
          find
              .ancestor(
                of: find.byKey(ValueKey('backup-schedule-${schedule.name}')),
                matching: find.byType(Material),
              )
              .first,
        )
        .color;

    await _pump(tester, BackupScreen(state: _state(BackupStatus.pending)));
    var colors = tester.element(find.byType(BackupScreen)).colorScheme;
    for (final schedule in BackupSchedule.values) {
      expect(cardColor(schedule), isNot(colors.primary));
    }

    await _pump(tester, BackupScreen(state: _state(BackupStatus.upToDate)));
    colors = tester.element(find.byType(BackupScreen)).colorScheme;
    expect(cardColor(BackupSchedule.weekly), colors.primary);
    expect(cardColor(BackupSchedule.daily), isNot(colors.primary));
    expect(cardColor(BackupSchedule.monthly), isNot(colors.primary));
  });

  testWidgets('mock actions show the preview notice', (tester) async {
    await _pump(
      tester,
      BackupScreen(state: _state(BackupStatus.pending)),
      locale: 'en',
    );
    final l10n = tester.element(find.byType(BackupScreen)).l10n;

    await tester.tap(find.byKey(const ValueKey('backup-now')));
    await tester.pump();
    expect(find.text(l10n.backupMockNotice), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('backup-schedule-monthly')));
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
}
