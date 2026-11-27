import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/utils/money_utils.dart';
import '../../domain/entities/customer_entity.dart';

class CustomerListCard extends StatelessWidget {
  const CustomerListCard({required this.customer, this.onTap, super.key});

  final CustomerEntity customer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final owes = customer.balancePiasters > 0;
    final formattedBalance = MoneyUtils.formatPiasters(
      customer.balancePiasters,
      locale: Localizations.localeOf(context).languageCode,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: AppSpacing.borderRadius,
        onTap:
            onTap ??
            () => context.pushNamed(
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
                    Text(
                      customer.phone ?? '',
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formattedBalance,
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
