import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/theme/app_theme.dart';
import 'package:daftariapp/core/utils/app_date_utils.dart';
import 'package:daftariapp/features/dashboard/domain/entities/dashboard_summary_entity.dart';
import 'package:daftariapp/features/dashboard/domain/entities/debtor_summary_entity.dart';
import 'package:daftariapp/features/dashboard/domain/entities/recent_activity_entity.dart';
import 'package:daftariapp/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:daftariapp/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:daftariapp/features/dashboard/presentation/widgets/dashboard_summary_card.dart';
import 'package:daftariapp/features/dashboard/presentation/widgets/recent_activity_row.dart';
import 'package:daftariapp/features/dashboard/presentation/widgets/top_debtor_row.dart';
import 'package:daftariapp/features/transactions/domain/entities/transaction_entity.dart';
import 'package:daftariapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

// Controls presentation states without starting repository watches or timers.
class _DashboardCubit extends Cubit<DashboardState> implements DashboardCubit {
  _DashboardCubit(super.initialState);

  int refreshes = 0;
  int resumeChecks = 0;

  void show(DashboardState state) => emit(state);

  @override
  Future<void> refresh() async {
    refreshes++;
    emit(DashboardState(summary: state.summary));
  }

  @override
  Future<void> refreshIfDayChanged() async => resumeChecks++;
}

void main() {
  setUpAll(AppDateUtils.initialize);
  const failure = AppFailure(AppErrorCode.database);
  final summary = DashboardSummaryEntity(
    totalOwedPiasters: 12345,
    debtorCount: 1,
    todayCollectionsPiasters: 205,
    topDebtors: const [
      DebtorSummaryEntity(
        id: 'customer',
        name: 'عميل Customer',
        phone: '01012345678',
        balancePiasters: 12345,
      ),
    ],
    recentActivity: [
      RecentActivityEntity(
        id: 'payment',
        customerId: 'customer',
        customerName: 'عميل Customer',
        type: TransactionType.payment,
        amountPiasters: 205,
        transactionDate: DateTime(2026, 11, 18, 12),
      ),
    ],
  );

  Future<void> mount(
    WidgetTester tester,
    _DashboardCubit cubit, {
    Locale locale = const Locale('en'),
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          locale: locale,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<DashboardCubit>.value(
            value: cubit,
            child: const DashboardScreen(),
          ),
        ),
      ),
    );
  }

  DashboardSummaryCard card(WidgetTester tester) =>
      tester.widget<DashboardSummaryCard>(find.byType(DashboardSummaryCard));

  for (final locale in [const Locale('ar'), const Locale('en')]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        '${locale.languageCode} ${mode.name}: live and empty states',
        (tester) async {
          final cubit = _DashboardCubit(
            DashboardState(loading: false, summary: summary),
          );
          await mount(tester, cubit, locale: locale, mode: mode);
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(DashboardScreen));
          final l10n = AppLocalizations.of(context)!;
          expect(
            Directionality.of(context),
            locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(
            Theme.of(context).brightness,
            mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
          );
          expect(find.text(l10n.dashboardTitle), findsOneWidget);
          expect(card(tester).totalOwedPiasters, 12345);
          expect(card(tester).debtorCount, 1);
          expect(card(tester).todayCollectionsPiasters, 205);
          expect(
            tester.widget<TopDebtorRow>(find.byType(TopDebtorRow)).debtor,
            summary.topDebtors.single,
          );
          await tester.ensureVisible(find.byType(RecentActivityRow));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<RecentActivityRow>(find.byType(RecentActivityRow))
                .activity,
            summary.recentActivity.single,
          );
          expect(find.text(l10n.dashboardUpdatedLive), findsOneWidget);
          expect(find.byIcon(Icons.notifications_outlined), findsNothing);
          cubit.show(
            const DashboardState(
              loading: false,
              summary: DashboardSummaryEntity.empty(),
            ),
          );
          await tester.pumpAndSettle();
          expect(card(tester).totalOwedPiasters, 0);
          expect(card(tester).debtorCount, 0);
          expect(card(tester).todayCollectionsPiasters, 0);
          expect(find.byType(TopDebtorRow), findsNothing);
          expect(find.byType(RecentActivityRow), findsNothing);
          expect(
            find.byKey(const ValueKey('dashboard-no-debtors')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('dashboard-no-activity')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );

      testWidgets(
        '${locale.languageCode} ${mode.name}: loading, error, retry',
        (tester) async {
          final cubit = _DashboardCubit(const DashboardState());
          await mount(tester, cubit, locale: locale, mode: mode);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(DashboardSummaryCard), findsNothing);
          cubit.show(const DashboardState(loading: false, failure: failure));
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(DashboardScreen)),
          )!;
          expect(find.text(l10n.errorTitle), findsOneWidget);
          expect(find.byType(DashboardSummaryCard), findsNothing);
          await tester.tap(find.byKey(const ValueKey('dashboard-retry')));
          await tester.pump();
          expect(cubit.refreshes, 1);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          cubit.show(DashboardState(loading: false, summary: summary));
          await tester.pumpAndSettle();
          expect(card(tester).totalOwedPiasters, 12345);
          expect(find.byKey(const ValueKey('dashboard-error')), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('pull gesture retains data, waits for failure, then recovers', (
    tester,
  ) async {
    final cubit = _DashboardCubit(
      DashboardState(loading: false, summary: summary),
    );
    await mount(tester, cubit);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(cubit.refreshes, 1);
    expect(card(tester).totalOwedPiasters, 12345);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    await tester.runAsync(() async {
      cubit.show(
        DashboardState(loading: false, summary: summary, failure: failure),
      );
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    // Cancellation's already-completed Future may originate outside fake async.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(card(tester).totalOwedPiasters, 12345);
    expect(find.byKey(const ValueKey('dashboard-error')), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(DashboardScreen)),
    )!;
    expect(find.text(l10n.dashboardUpdatedLive), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('dashboard-retry')));
    await tester.tap(find.byKey(const ValueKey('dashboard-retry')));
    await tester.pump();
    expect(cubit.refreshes, 2);
    await tester.runAsync(() async {
      cubit.show(DashboardState(loading: false, summary: summary));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dashboard-error')), findsNothing);
    expect(find.text(l10n.dashboardUpdatedLive), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('short error content supports pull gesture and close completion', (
    tester,
  ) async {
    final cubit = _DashboardCubit(
      const DashboardState(loading: false, failure: failure),
    );
    await mount(tester, cubit);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(cubit.refreshes, 1);
    // Closing during refresh must release the screen's pending refresh Future.
    await tester.runAsync(cubit.close);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('resumed observer unregisters when the screen is disposed', (
    tester,
  ) async {
    final cubit = _DashboardCubit(
      const DashboardState(
        loading: false,
        summary: DashboardSummaryEntity.empty(),
      ),
    );
    await mount(tester, cubit);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(cubit.resumeChecks, 1);
    await tester.pumpWidget(const SizedBox());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(cubit.resumeChecks, 1);
    expect(tester.takeException(), isNull);
  });
}
