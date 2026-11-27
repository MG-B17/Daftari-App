import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../transactions/presentation/widgets/customer_transactions_section.dart';
import '../../domain/entities/customer_entity.dart';
import '../cubit/customer_details_cubit.dart';

class CustomerDetailsBody extends StatelessWidget {
  const CustomerDetailsBody({
    super.key,
    required this.customer,
    this.launchPhone = launchUrl,
    this.deleting = false,
  });

  final CustomerEntity customer;
  final Future<bool> Function(Uri) launchPhone;
  final bool deleting;

  Future<void> _call(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.customerCallError;
    var launched = false;
    try {
      launched = await launchPhone(Uri(scheme: 'tel', path: customer.phone));
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<CustomerDetailsCubit>();
    while (context.mounted) {
      final current = cubit.state.customer;
      if (current == null) return;
      final balance = current.balancePiasters;
      final confirmed = await AppConfirmationDialog.show(
        context,
        title: context.l10n.customerDelete,
        message: balance == 0
            ? context.l10n.customerDeleteMessage
            : context.l10n.customerDeleteBalanceMessage(
                MoneyUtils.formatPiasters(
                  balance,
                  locale: Localizations.localeOf(context).languageCode,
                ),
              ),
        confirmLabel: context.l10n.customerDelete,
        isDestructive: true,
      );
      if (!context.mounted || !confirmed) return;
      if (cubit.state.customer?.balancePiasters == balance) {
        await cubit.delete();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Card(
            key: const ValueKey('customer-details-card'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: AppSpacing.customersAvatarRadius,
                        backgroundColor:
                            context.appColors.customersAccentSurface,
                        child: Text(customer.name.characters.first),
                      ),
                      SizedBox(width: AppSpacing.compact),
                      Expanded(
                        child: Text(
                          customer.name,
                          style: context.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('customer-edit'),
                        tooltip: l10n.customerEdit,
                        onPressed: deleting
                            ? null
                            : () => context.pushNamed(
                                AppRoutes.customerEditName,
                                pathParameters: {'id': customer.id},
                              ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: AppSpacing.pagePadding,
                    decoration: BoxDecoration(
                      color: context.appColors.customersAccentSurface,
                      borderRadius: AppSpacing.borderRadius,
                    ),
                    child: Column(
                      children: [
                        Text(l10n.customerBalance, textAlign: TextAlign.center),
                        SizedBox(height: AppSpacing.sm),
                        Text(
                          MoneyUtils.formatPiasters(
                            customer.balancePiasters,
                            locale: Localizations.localeOf(context)
                                .languageCode,
                          ),
                          style: context.textTheme.headlineMedium?.copyWith(
                            color: customer.balancePiasters > 0
                                ? context.colorScheme.error
                                : context.appColors.paymentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customer.phone ?? '',
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('customer-call'),
                        onPressed:
                            deleting ||
                                customer.phone == null ||
                                customer.phone!.isEmpty
                            ? null
                            : () => _call(context),
                        icon: const Icon(Icons.phone_outlined),
                        label: Text(l10n.customerCall),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg),
                  FilledButton.tonalIcon(
                    key: const ValueKey('customer-statement'),
                    onPressed: deleting
                        ? null
                        : () => context.pushNamed(
                            AppRoutes.customerStatementName,
                            pathParameters: {'id': customer.id},
                          ),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.statementShareWithCustomer),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  AppButton(
                    key: const ValueKey('customer-delete'),
                    label: l10n.customerDelete,
                    icon: Icons.delete_outline,
                    variant: AppButtonVariant.outlined,
                    fullWidth: true,
                    isLoading: deleting,
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
            ),
          ),
        ),
        CustomerTransactionsSection(customerId: customer.id),
      ],
    );
  }
}
