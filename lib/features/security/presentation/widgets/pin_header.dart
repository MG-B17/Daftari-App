import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class PinHeader extends StatelessWidget {
  const PinHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: AppSpacing.pinLogoSize,
        height: AppSpacing.pinLogoSize,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: context.appColors.lockAccentSurface,
                  borderRadius: AppSpacing.borderRadius,
                  border: Border.all(
                    color: context.colorScheme.primaryContainer,
                  ),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: AppSpacing.pinBookSize,
                  color: context.colorScheme.primary,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: AppSpacing.pinBadgeSize,
                height: AppSpacing.pinBadgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colorScheme.primary,
                  border: Border.all(
                    color: context.appColors.paperBackground,
                    width: AppSpacing.selectedStroke,
                  ),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: AppSpacing.pinBadgeIconSize,
                  color: context.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: AppSpacing.md),
      Text(
        context.l10n.securityBrandCaption,
        textAlign: TextAlign.center,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      SizedBox(height: AppSpacing.sm),
      Text(
        title,
        style: context.textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      SizedBox(height: AppSpacing.sm),
      Text(subtitle, textAlign: TextAlign.center),
    ],
  );
}
