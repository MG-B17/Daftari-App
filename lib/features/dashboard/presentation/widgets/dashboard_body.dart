import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/daftari_loading.dart';
import '../cubit/dashboard_cubit.dart';
import 'dashboard_header.dart';
import 'dashboard_summary_card.dart';
import 'dashboard_tip_card.dart';
import 'recent_activity_section.dart';
import 'top_debtors_section.dart';

class DashboardBody extends StatelessWidget {
  const DashboardBody({
    super.key,
    required this.state,
    required this.onRefresh,
  });

  final DashboardState state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    void openCustomer(String id) => context.pushNamed(
      AppRoutes.customerDetailsName,
      pathParameters: {'id': id},
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: const PageStorageKey('dashboard-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (summary == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: state.loading
                  ? const DaftariLoading.screen()
                  : Center(child: _DashboardError(onRetry: onRefresh)),
            )
          else
            SliverPadding(
              padding: AppSpacing.pagePadding,
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DashboardHeader(),
                    SizedBox(height: AppSpacing.md),
                    if (state.loading) ...[
                      const Center(child: DaftariLoading.inline()),
                      SizedBox(height: AppSpacing.md),
                    ],
                    if (state.failure != null) ...[
                      _DashboardError(onRetry: onRefresh),
                      SizedBox(height: AppSpacing.md),
                    ],
                    DashboardSummaryCard(
                      totalOwedPiasters: summary.totalOwedPiasters,
                      debtorCount: summary.debtorCount,
                      todayCollectionsPiasters:
                          summary.todayCollectionsPiasters,
                      onRegisterTransaction: () =>
                          context.push(AppRoutes.transactionNew),
                      onNewCustomer: () => context.push(AppRoutes.customerNew),
                    ),
                    SizedBox(height: AppSpacing.lg),
                    TopDebtorsSection(
                      debtors: summary.topDebtors,
                      onViewAll: () => context.go(AppRoutes.customers),
                      onOpenCustomer: openCustomer,
                    ),
                    SizedBox(height: AppSpacing.lg),
                    RecentActivitySection(
                      activities: summary.recentActivity,
                      updatedLive: !state.loading && state.failure == null,
                      onOpenCustomer: openCustomer,
                    ),
                    SizedBox(height: AppSpacing.md),
                    const DashboardTipCard(),
                    SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('dashboard-error'),
    padding: AppSpacing.dashboardCardPadding,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.errorTitle,
          style: context.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        Text(context.l10n.errorMessage, textAlign: TextAlign.center),
        TextButton(
          key: const ValueKey('dashboard-retry'),
          onPressed: onRetry,
          child: Text(context.l10n.retry),
        ),
      ],
    ),
  );
}
