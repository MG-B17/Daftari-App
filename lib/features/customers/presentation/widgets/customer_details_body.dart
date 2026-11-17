import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money_utils.dart';
import '../customer_mock_data.dart';

class CustomerDetailsBody extends StatelessWidget {
  const CustomerDetailsBody({
    super.key,
    required this.customer,
    this.launchPhone = launchUrl,
  });

  final CustomerMock customer;
  final Future<bool> Function(Uri) launchPhone;

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: AppSpacing.customersMaxWidth),
        child: ListView(
          children: [
            Card(
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
                          tooltip: l10n.customerEdit,
                          onPressed: () => context.pushNamed(
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
                          Text(
                            l10n.customerBalance,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: AppSpacing.sm),
                          Text(
                            MoneyUtils.formatPiasters(
                              customer.balance,
                              locale: Localizations.localeOf(context)
                                  .languageCode,
                            ),
                            style: context.textTheme.headlineMedium?.copyWith(
                              color: customer.balance > 0
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
                            customer.phone,
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('customer-call'),
                          onPressed: () => _call(context),
                          icon: const Icon(Icons.phone_outlined),
                          label: Text(l10n.customerCall),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
