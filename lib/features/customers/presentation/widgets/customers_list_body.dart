import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animation/staggered_list_item.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../../core/widgets/daftari_loading.dart';
import '../../domain/entities/customer_entity.dart';
import '../cubit/customers_list_cubit.dart';
import '../customer_error_message.dart';
import 'customer_list_card.dart';

class CustomersListBody extends StatelessWidget {
  const CustomersListBody({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<CustomersListCubit, CustomersListState>(
    builder: (context, state) {
      final l10n = context.l10n;
      final customers = state.customers;
      final owing = state.owing;
      final visible = state.visible;
      final total = state.totalDebt;
      if (state.loading) {
        return const DaftariLoading.screen();
      }
      if (state.failure != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(customerErrorMessage(context, state.failure!.errorCode)),
              TextButton(
                onPressed: () => context.read<CustomersListCubit>().load(),
                child: Text(l10n.retry),
              ),
            ],
          ),
        );
      }

      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                children: [
                  _SearchTrigger(
                    onTap: () => context.pushNamed(AppRoutes.searchName),
                  ),
                  SizedBox(height: AppSpacing.md),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in CustomerFilter.values) ...[
                          ChoiceChip(
                            key: ValueKey('customers-filter-${filter.name}'),
                            label: Text(switch (filter) {
                              CustomerFilter.all =>
                                '${l10n.customersAll} ${customers.length}',
                              CustomerFilter.owes =>
                                '${l10n.customersOwes} $owing',
                              CustomerFilter.settled =>
                                '${l10n.customersSettled} ${state.settled}',
                            }),
                            selected: state.filter == filter,
                            onSelected: (_) => context
                                .read<CustomersListCubit>()
                                .setFilter(filter),
                          ),
                          SizedBox(width: AppSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: PopupMenuButton<CustomerSort>(
                      key: const ValueKey('customers-sort'),
                      tooltip: l10n.customersSort,
                      icon: const Icon(Icons.sort),
                      onSelected: context.read<CustomersListCubit>().setSort,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: CustomerSort.nameAsc,
                          child: Text(l10n.customersSortName),
                        ),
                        PopupMenuItem(
                          value: CustomerSort.balanceDesc,
                          child: Text(l10n.customersSortBalance),
                        ),
                        PopupMenuItem(
                          value: CustomerSort.recent,
                          child: Text(l10n.customersSortRecent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (customers.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyCustomers(
                onAdd: () => context.push(AppRoutes.customerNew),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: AppSpacing.pagePadding,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l10n.customersCount(customers.length, owing)),
                    ),
                    Flexible(
                      child: Text(
                        '${l10n.customersTotalDebt}: ${_money(context, total)}',
                        textAlign: TextAlign.end,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (visible.isEmpty)
              SliverToBoxAdapter(
                child: Center(child: Text(l10n.customersNoResults)),
              )
            else
              SliverPadding(
                padding: AppSpacing.pagePadding,
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => StaggeredListItem(
                    key: ValueKey(visible[index].id),
                    index: index,
                    child: CustomerListCard(customer: visible[index]),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.customersListBottomInset),
            ),
          ],
        ],
      );
    },
  );
}

String _money(BuildContext context, int value) => MoneyUtils.formatPiasters(
  value,
  locale: Localizations.localeOf(context).languageCode,
);

class _SearchTrigger extends StatelessWidget {
  const _SearchTrigger({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hint = context.l10n.customersSearch;
    return Semantics(
      button: true,
      label: hint,
      child: Material(
        key: const ValueKey('customers-search'),
        color: context.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadius,
          side: BorderSide(color: context.colorScheme.outline),
        ),
        child: InkWell(
          borderRadius: AppSpacing.borderRadius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: AppSpacing.searchTriggerHeight,
            ),
            child: Padding(
              padding: AppSpacing.searchTriggerPadding,
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: AppSpacing.compact),
                  Expanded(
                    child: Text(
                      hint,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: AppSpacing.pagePadding,
    child: Card(
      key: const ValueKey('customers-empty-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          children: [
            SizedBox(height: AppSpacing.xl),
            SvgPicture.asset(
              'assets/svgs/empty_icon.svg',
              width: AppSpacing.customersIllustrationSize,
              height: AppSpacing.customersIllustrationSize,
              excludeFromSemantics: true,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(context.l10n.customersEmptyBadge),
            SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.customersEmptyTitle,
              style: context.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.customersEmptyMessage,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add_alt),
                label: Text(context.l10n.customersAddFirst),
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await context
                      .read<CustomersListCubit>()
                      .pickContact();
                  if (!context.mounted) return;
                  result.fold(
                    (failure) => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          customerErrorMessage(context, failure.errorCode),
                        ),
                      ),
                    ),
                    (contact) {
                      if (contact != null) {
                        context.push(AppRoutes.customerNew, extra: contact);
                      }
                    },
                  );
                },
                icon: const Icon(Icons.contacts_outlined),
                label: Text(context.l10n.customerImport),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
