import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class SearchIllustrationState extends StatelessWidget {
  const SearchIllustrationState({
    required this.title,
    required this.message,
    required this.illustrationLabel,
    required this.staticIcon,
    super.key,
  });

  static const assetPath = 'assets/lottie/Not Found.json';

  final String title;
  final String message;
  final String illustrationLabel;
  final IconData staticIcon;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dimension = AppSpacing.searchIllustrationSize;
    final staticEquivalent = Center(
      child: Container(
        width: AppSpacing.feedbackDialogBadgeSize,
        height: AppSpacing.feedbackDialogBadgeSize,
        decoration: BoxDecoration(
          color: context.appColors.customersAccentSurface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          staticIcon,
          size: AppSpacing.feedbackDialogIconSize,
          color: context.colorScheme.primary,
        ),
      ),
    );

    final visual = SizedBox.square(
      dimension: dimension,
      child: reduceMotion
          ? staticEquivalent
          : Lottie.asset(
              assetPath,
              width: dimension,
              height: dimension,
              fit: BoxFit.contain,
              repeat: true,
              frameBuilder: (_, child, composition) =>
                  composition == null ? staticEquivalent : child,
              errorBuilder: (_, _, _) => staticEquivalent,
            ),
    );

    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: illustrationLabel,
              image: true,
              excludeSemantics: true,
              child: visual,
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: context.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
