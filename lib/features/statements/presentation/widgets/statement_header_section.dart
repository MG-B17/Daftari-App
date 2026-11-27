import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/customer_statement_entity.dart';

class StatementHeaderSection extends StatelessWidget {
  const StatementHeaderSection({super.key, required this.statement});

  final CustomerStatementEntity statement;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: AppSpacing.statementBrandBar,
          color: context.appColors.brand,
        ),
        Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    color: context.colorScheme.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      context.l10n.appTitle,
                      style: context.textTheme.titleLarge,
                    ),
                  ),
                  Icon(
                    Icons.receipt_long_outlined,
                    color: context.colorScheme.primary,
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                context.l10n.statementGeneratedAt(
                  AppDateUtils.formatDate(
                    statement.generatedAt,
                    locale: locale,
                  ),
                  AppDateUtils.formatTime(
                    statement.generatedAt,
                    locale: locale,
                  ),
                ),
                style: context.textTheme.bodySmall,
              ),
              SizedBox(height: AppSpacing.md),
              Container(
                padding: AppSpacing.controlPadding,
                decoration: BoxDecoration(
                  color: context.appColors.customersAccentSurface,
                  borderRadius: AppSpacing.borderRadius,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(statement.customer.name),
                          if (statement.customer.phone?.trim().isNotEmpty ??
                              false)
                            Text(
                              statement.customer.phone!.trim(),
                              textDirection: TextDirection.ltr,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
