import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Column(
      children: [
        Container(
          width: AppSpacing.authHeroSize,
          height: AppSpacing.authHeroSize,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: AppSpacing.authHeroIcon,
            color: colors.onPrimaryContainer,
          ),
        ),
        if (badge != null)
          Transform.translate(
            offset: Offset(0, -AppSpacing.compact),
            child: Container(
              padding: AppSpacing.badgePadding,
              decoration: BoxDecoration(
                color: context.appColors.paymentSurface,
                borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: AppSpacing.authBadgeIcon,
                    color: context.appColors.paymentColor,
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    badge!,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.appColors.paymentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: badge == null ? AppSpacing.md : AppSpacing.xs),
        Text(
          title,
          textAlign: TextAlign.center,
          style: context.textTheme.titleLarge,
        ),
        SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
