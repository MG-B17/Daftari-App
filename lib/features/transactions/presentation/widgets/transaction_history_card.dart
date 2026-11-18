import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../domain/entities/transaction_entity.dart';
import '../cubit/customer_transactions_cubit.dart';

class TransactionHistoryCard extends StatelessWidget {
  const TransactionHistoryCard({
    super.key,
    required this.entry,
    required this.balance,
    required this.deleting,
  });

  final TransactionEntity entry;
  final String balance;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final credit = entry.type == TransactionType.credit;
    final color = credit
        ? context.appColors.creditColor
        : context.appColors.paymentColor;
    return Card(
      child: Padding(
        padding: AppSpacing.customersCardPadding,
        child: Column(
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Container(
                  padding: AppSpacing.badgePadding,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                  ),
                  child: Text(
                    credit
                        ? l10n.transactionCreditBadge
                        : l10n.transactionPaymentBadge,
                    style: TextStyle(color: color),
                  ),
                ),
                if (entry.note != null && entry.note!.isNotEmpty)
                  Text(entry.note!),
                Text(
                  '${credit ? '-' : '+'}${MoneyUtils.formatPiasters(entry.amountPiasters, locale: locale)}',
                  style: TextStyle(color: color),
                ),
                PopupMenuButton<String>(
                  enabled: !deleting,
                  onSelected: (action) async {
                    if (action == 'edit') {
                      context.pushNamed(
                        AppRoutes.transactionEditName,
                        pathParameters: {'id': entry.id},
                      );
                    } else {
                      final cubit = context.read<CustomerTransactionsCubit>();
                      final confirmed = await AppConfirmationDialog.show(
                        context,
                        title: l10n.transactionDeleteAction,
                        message: l10n.transactionDeleteMessage,
                        confirmLabel: l10n.transactionDeleteAction,
                        isDestructive: true,
                      );
                      if (confirmed && context.mounted) {
                        await cubit.delete(entry.id);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(l10n.transactionEditAction),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.transactionDeleteAction),
                    ),
                  ],
                ),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Icon(Icons.access_time, size: AppSpacing.iconSmall),
                Text(
                  AppDateUtils.formatTime(
                    entry.transactionDate,
                    locale: locale,
                  ),
                ),
                Text('${l10n.transactionBalance}: $balance'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
