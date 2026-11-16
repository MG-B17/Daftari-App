import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class SplashBranding extends StatelessWidget {
  const SplashBranding({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSpacing.splashLogoSize,
            height: AppSpacing.splashLogoSize,
            decoration: BoxDecoration(
              color: context.appColors.brand,
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            ),
            child: Center(
              child: Image.asset(
                'assets/icons/app_icon_foreground.png',
                width: AppSpacing.splashLogoImageSize,
                height: AppSpacing.splashLogoImageSize,
                excludeFromSemantics: true,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            l10n.appTitle,
            textAlign: TextAlign.center,
            style: context.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            l10n.splashTagline,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
