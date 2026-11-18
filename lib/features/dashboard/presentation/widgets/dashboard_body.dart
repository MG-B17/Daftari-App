import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import 'dashboard_header.dart';
import 'dashboard_summary_card.dart';
import 'dashboard_tip_card.dart';
import 'recent_activity_row.dart';
import 'recent_activity_section.dart';
import 'top_debtor_row.dart';
import 'top_debtors_section.dart';

class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final debtors = <TopDebtorPreview>[
      (
        name: l10n.customersSample1,
        phone: '01012345678',
        balancePiasters: 320000,
      ),
      (
        name: l10n.customersSample2,
        phone: '01124567890',
        balancePiasters: 245000,
      ),
      (
        name: l10n.customersSample3,
        phone: '01234567891',
        balancePiasters: 185000,
      ),
    ];
    final activities = <RecentActivityPreview>[
      (
        customerName: l10n.customersSample4,
        amountPiasters: 45000,
        date: now.subtract(const Duration(minutes: 35)),
        credit: true,
        note: l10n.transactionSampleCredit,
      ),
      (
        customerName: l10n.customersSample7,
        amountPiasters: 100000,
        date: now.subtract(const Duration(hours: 3)),
        credit: false,
        note: l10n.transactionSamplePayment,
      ),
      (
        customerName: l10n.customersSample5,
        amountPiasters: 50000,
        date: now.subtract(const Duration(days: 1, hours: 2)),
        credit: false,
        note: l10n.transactionSamplePayment,
      ),
      (
        customerName: l10n.customersSample6,
        amountPiasters: 75000,
        date: now.subtract(const Duration(days: 1, hours: 5)),
        credit: true,
        note: l10n.transactionSampleCredit,
      ),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: AppSpacing.dashboardMaxWidth),
        child: SingleChildScrollView(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DashboardHeader(),
              SizedBox(height: AppSpacing.md),
              DashboardSummaryCard(
                totalOwedPiasters: 1245000,
                debtorCount: 18,
                todayCollectionsPiasters: 150000,
                onRegisterTransaction: () =>
                    context.push(AppRoutes.transactionNew),
                onNewCustomer: () => context.push(AppRoutes.customerNew),
              ),
              SizedBox(height: AppSpacing.lg),
              TopDebtorsSection(
                debtors: debtors,
                onViewAll: () => context.go(AppRoutes.customers),
              ),
              SizedBox(height: AppSpacing.lg),
              RecentActivitySection(activities: activities),
              SizedBox(height: AppSpacing.md),
              const DashboardTipCard(),
              SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
