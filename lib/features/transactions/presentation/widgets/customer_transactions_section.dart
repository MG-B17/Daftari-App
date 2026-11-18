import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/money_utils.dart';
import '../cubit/customer_transactions_cubit.dart';
import 'transaction_history_card.dart';

class CustomerTransactionsSection extends StatelessWidget {
  const CustomerTransactionsSection({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<CustomerTransactionsCubit>()..load(customerId),
    child: _History(customerId: customerId),
  );
}

class _History extends StatelessWidget {
  const _History({required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    void open(String type) => context.pushNamed(
      AppRoutes.transactionNewName,
      queryParameters: {'customerId': customerId, 'type': type},
    );
    return BlocConsumer<CustomerTransactionsCubit, CustomerTransactionsState>(
      listenWhen: (previous, current) =>
          current.failure != null && previous.failure != current.failure,
      listener: (context, state) {
        if (state.failure != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.transactionHistoryError)));
        }
      },
      builder: (context, state) {
        String balance(BigInt value) {
          if (value.abs() > BigInt.from(MoneyUtils.maxPiasters)) {
            return l10n.transactionBalanceUnavailable;
          }
          return MoneyUtils.formatPiasters(value.toInt(), locale: locale);
        }

        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => open('credit'),
                          style: FilledButton.styleFrom(
                            backgroundColor: context.appColors.creditColor,
                          ),
                          icon: const Icon(Icons.add_circle_outline),
                          label: Text(l10n.transactionCredit),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => open('payment'),
                          style: FilledButton.styleFrom(
                            backgroundColor: context.appColors.paymentColor,
                          ),
                          icon: const Icon(Icons.payments_outlined),
                          label: Text(l10n.transactionPayment),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    children: [
                      Text(
                        l10n.transactionHistory,
                        style: context.textTheme.titleLarge,
                      ),
                      Chip(
                        label: Text(
                          l10n.transactionCount(state.entries.length),
                        ),
                      ),
                    ],
                  ),
                  if (state.loading)
                    const Center(child: CircularProgressIndicator())
                  else if (state.failure != null && state.entries.isEmpty)
                    TextButton(
                      onPressed: () => context
                          .read<CustomerTransactionsCubit>()
                          .load(customerId),
                      child: Text(l10n.retry),
                    )
                  else if (state.entries.isEmpty)
                    Text(l10n.transactionHistoryEmpty),
                ],
              ),
            ),
            if (!state.loading && state.entries.isNotEmpty)
              SliverList.builder(
                itemCount: state.entries.length,
                itemBuilder: (context, index) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (index == 0 ||
                        !DateUtils.isSameDay(
                          state.entries[index - 1].transactionDate.toLocal(),
                          state.entries[index].transactionDate.toLocal(),
                        ))
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Text(
                          AppDateUtils.relativeDay(
                            state.entries[index].transactionDate,
                            locale: locale,
                          ),
                          style: context.textTheme.titleSmall,
                        ),
                      ),
                    TransactionHistoryCard(
                      entry: state.entries[index],
                      balance: balance(
                        state.runningBalances[state.entries[index].id]!,
                      ),
                      deleting: state.deleting,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
