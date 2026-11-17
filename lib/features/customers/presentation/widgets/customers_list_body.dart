import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money_utils.dart';
import '../customer_mock_data.dart';

enum _Filter { all, owes, settled }

class CustomersListBody extends StatefulWidget {
  const CustomersListBody({super.key, required this.showMockCustomers});

  final bool showMockCustomers;

  @override
  State<CustomersListBody> createState() => _CustomersListBodyState();
}

class _CustomersListBodyState extends State<CustomersListBody> {
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final customers = widget.showMockCustomers
        ? mockCustomers(l10n)
        : <CustomerMock>[];
    final owing = customers.where((customer) => customer.balance > 0).length;
    final visible = customers.where((customer) {
      final matches =
          customer.name.toLowerCase().contains(_query) ||
          customer.phone.contains(_query);
      return matches &&
          switch (_filter) {
            _Filter.all => true,
            _Filter.owes => customer.balance > 0,
            _Filter.settled => customer.balance == 0,
          };
    }).toList();
    final total = customers.fold<int>(0, (sum, item) => sum + item.balance);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: AppSpacing.customersMaxWidth),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  children: [
                    TextField(
                      key: const ValueKey('customers-search'),
                      onChanged: (value) => setState(
                        () =>
                            _query = value.trim().toLowerCase().toWesternDigits,
                      ),
                      decoration: InputDecoration(
                        hintText: l10n.customersSearch,
                        prefixIcon: const Icon(Icons.search),
                        fillColor: context.colorScheme.surface,
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final filter in _Filter.values) ...[
                            ChoiceChip(
                              key: ValueKey('customers-filter-${filter.name}'),
                              label: Text(switch (filter) {
                                _Filter.all =>
                                  '${l10n.customersAll} ${customers.length}',
                                _Filter.owes => '${l10n.customersOwes} $owing',
                                _Filter.settled =>
                                  '${l10n.customersSettled} ${customers.length - owing}',
                              }),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                            ),
                            SizedBox(width: AppSpacing.sm),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (customers.isEmpty)
              SliverToBoxAdapter(child: _EmptyCustomers(onAdd: _openNew))
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.pagePadding,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.customersCount(customers.length, owing),
                        ),
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
                    itemBuilder: (context, index) =>
                        _CustomerCard(customer: visible[index]),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.customersListBottomInset),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openNew() => context.push(AppRoutes.customerNew);
}

String _money(BuildContext context, int value) => MoneyUtils.formatPiasters(
  value,
  locale: Localizations.localeOf(context).languageCode,
);

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});
  final CustomerMock customer;

  @override
  Widget build(BuildContext context) {
    final owes = customer.balance > 0;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: AppSpacing.borderRadius,
        onTap: () => context.pushNamed(
          AppRoutes.customerDetailsName,
          pathParameters: {'id': customer.id},
        ),
        child: Padding(
          padding: AppSpacing.customersCardPadding,
          child: Row(
            children: [
              CircleAvatar(
                radius: AppSpacing.customersAvatarRadius,
                backgroundColor: context.appColors.customersAccentSurface,
                child: Text(customer.name.characters.first),
              ),
              SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name, style: context.textTheme.titleSmall),
                    Text(customer.phone, textDirection: TextDirection.ltr),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _money(context, customer.balance),
                    style: context.textTheme.titleSmall?.copyWith(
                      color: owes
                          ? context.colorScheme.error
                          : context.appColors.paymentColor,
                    ),
                  ),
                  Text(
                    owes
                        ? context.l10n.customersOwes
                        : context.l10n.customersSettled,
                  ),
                ],
              ),
            ],
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
                onPressed: null,
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
