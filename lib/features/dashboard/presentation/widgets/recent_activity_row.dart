import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/recent_activity_entity.dart';

class RecentActivityRow extends StatelessWidget {
  const RecentActivityRow({
    super.key,
    required this.activity,
    required this.onTap,
  });

  final RecentActivityEntity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final color = activity.isCredit
        ? context.appColors.creditColor
        : context.appColors.paymentColor;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.dashboardCardPadding,
        child: Row(
          children: [
            Container(
              width: AppSpacing.dashboardActivityIconBox,
              height: AppSpacing.dashboardActivityIconBox,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                activity.isCredit ? Icons.arrow_downward : Icons.check,
                size: AppSpacing.iconSmall,
                color: color,
              ),
            ),
            SizedBox(width: AppSpacing.compact),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall,
                  ),
                  Text(
                    l10n
                        .dashboardActivityDate(
                          AppDateUtils.relativeDay(
                            activity.transactionDate,
                            locale: locale,
                          ),
                          AppDateUtils.formatTime(
                            activity.transactionDate,
                            locale: locale,
                          ),
                        )
                        .toWesternDigits,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Flexible(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      context.formatMoney(activity.amountPiasters),
                      maxLines: 1,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: color,
                      ),
                    ),
                  ),
                  if (activity.note != null)
                    Text(
                      activity.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Container(
                padding: AppSpacing.badgePadding,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    activity.isCredit
                        ? l10n.transactionCreditBadge
                        : l10n.transactionPaymentBadge,
                    maxLines: 1,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
