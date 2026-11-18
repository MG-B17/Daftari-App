import 'package:daftariapp/app.dart';
import 'package:daftariapp/core/database/app_database.dart';
import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/routing/app_router.dart';
import 'package:daftariapp/features/dashboard/domain/entities/dashboard_summary_entity.dart';
import 'package:daftariapp/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:daftariapp/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:daftariapp/features/dashboard/presentation/widgets/dashboard_summary_card.dart';
import 'package:daftariapp/features/dashboard/presentation/widgets/recent_activity_row.dart';
import 'package:daftariapp/features/dashboard/presentation/widgets/top_debtor_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../customer_test_setup.dart';

void main() {
  tearDown(() => sl.reset());

  testWidgets(
    'live deletion excludes customers and transactions without refresh',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = (await tester.runAsync(
        () => setupCustomerTests(seed: false),
      ))!;
      final first = (await tester.runAsync(
        () => database.customerDao.createCustomer(name: 'Deleted customer'),
      ))!;
      final second = (await tester.runAsync(
        () => database.customerDao.createCustomer(name: 'Surviving customer'),
      ))!;
      await tester.runAsync(() async {
        await database.transactionDao.createTransaction(
          customerId: first.id,
          type: TransactionTypes.credit,
          amountPiasters: 10000,
        );
        await database.transactionDao.createTransaction(
          customerId: first.id,
          type: TransactionTypes.payment,
          amountPiasters: 1000,
        );
        await database.transactionDao.createTransaction(
          customerId: second.id,
          type: TransactionTypes.credit,
          amountPiasters: 5000,
        );
      });
      final payment = (await tester.runAsync(
        () => database.transactionDao.createTransaction(
          customerId: second.id,
          type: TransactionTypes.payment,
          amountPiasters: 500,
        ),
      ))!;
      final router = AppRouter.create();
      await tester.pumpWidget(DaftariApp(router: router));
      await tester.pumpAndSettle();
      final cubit = tester
          .element(find.byType(DashboardScreen))
          .read<DashboardCubit>();

      void expectSummary(int owed, int debtors, int collections) {
        final card = tester.widget<DashboardSummaryCard>(
          find.byType(DashboardSummaryCard),
        );
        expect(card.totalOwedPiasters, owed);
        expect(card.debtorCount, debtors);
        expect(card.todayCollectionsPiasters, collections);
      }

      Future<void> mutate(
        Future<void> Function() action,
        bool Function(DashboardSummaryEntity) matches,
      ) async {
        await tester.runAsync(action);
        await tester.pumpAndSettle();
        expect(cubit.state.summary, isNotNull);
        expect(matches(cubit.state.summary!), isTrue);
      }

      expectSummary(13500, 2, 1500);
      expect(find.byType(TopDebtorRow), findsNWidgets(2));
      expect(find.byType(RecentActivityRow), findsNWidgets(4));
      await mutate(
        () => database.transactionDao.softDeleteTransaction(payment.id),
        (value) =>
            value.totalOwedPiasters == 14000 &&
            value.todayCollectionsPiasters == 1000 &&
            value.recentActivity.length == 3,
      );
      expectSummary(14000, 2, 1000);
      expect(
        find.byKey(ValueKey('dashboard-activity-${payment.id}')),
        findsNothing,
      );
      await mutate(
        () => database.customerDao.softDeleteCustomer(first.id),
        (value) =>
            value.totalOwedPiasters == 5000 &&
            value.debtorCount == 1 &&
            value.todayCollectionsPiasters == 0 &&
            value.recentActivity.length == 1,
      );
      expectSummary(5000, 1, 0);
      expect(
        find.byKey(ValueKey('dashboard-debtor-${first.id}')),
        findsNothing,
      );
      expect(
        tester.widget<TopDebtorRow>(find.byType(TopDebtorRow)).debtor.id,
        second.id,
      );
      expect(
        tester
            .widget<RecentActivityRow>(find.byType(RecentActivityRow))
            .activity
            .customerId,
        second.id,
      );
      await mutate(
        () => database.customerDao.softDeleteCustomer(second.id),
        (value) => value == const DashboardSummaryEntity.empty(),
      );
      expectSummary(0, 0, 0);
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
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
    },
  );
}
