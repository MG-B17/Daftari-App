import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_date_utils.dart';

typedef RecentActivityPreview = ({
  String customerName,
  int amountPiasters,
  DateTime date,
  bool credit,
  String? note,
});

class RecentActivityRow extends StatelessWidget {
  const RecentActivityRow({super.key, required this.activity});

  final RecentActivityPreview activity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final color = activity.credit
        ? context.appColors.creditColor
        : context.appColors.paymentColor;
    return Padding(
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
              activity.credit ? Icons.arrow_downward : Icons.check,
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
                        AppDateUtils.relativeDay(activity.date, locale: locale),
                        AppDateUtils.formatTime(activity.date, locale: locale),
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
                  activity.credit
                      ? l10n.transactionCreditBadge
                      : l10n.transactionPaymentBadge,
                  maxLines: 1,
                  style: context.textTheme.labelMedium?.copyWith(color: color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
