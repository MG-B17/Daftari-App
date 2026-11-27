import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';

class SplashBranding extends StatelessWidget {
  const SplashBranding({super.key});

  static const assetPath = 'assets/lottie/splash_icon.json';
  static const _animatedScale = 1.45;
  static const _animatedOffsetXFactor = 0.022;
  static const _animatedOffsetYFactor = 0.072;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final logoSize = AppSpacing.splashLogoSize;
    final borderRadius = BorderRadius.circular(AppSpacing.pillRadius);
    final staticLogo = Image.asset(
      'assets/icons/app_icon_foreground.png',
      width: AppSpacing.splashLogoImageSize,
      height: AppSpacing.splashLogoImageSize,
      excludeFromSemantics: true,
    );

    final logoVisual = reduceMotion
        ? staticLogo
        : Lottie.asset(
            assetPath,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
            repeat: false,
            delegates: LottieDelegates(
              values: [
                ValueDelegate.opacity(const ['wordmark'], value: 0),
              ],
            ),
            frameBuilder: (_, child, composition) => composition == null
                ? staticLogo
                : Transform.scale(
                    scale: _animatedScale,
                    child: Transform.translate(
                      offset: Offset(
                        logoSize * _animatedOffsetXFactor,
                        logoSize * _animatedOffsetYFactor,
                      ),
                      child: child,
                    ),
                  ),
            errorBuilder: (_, _, _) => staticLogo,
          );

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: l10n.appTitle,
            image: true,
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: borderRadius,
              child: Container(
                width: logoSize,
                height: logoSize,
                color: context.appColors.brand,
                alignment: Alignment.center,
                child: logoVisual,
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
