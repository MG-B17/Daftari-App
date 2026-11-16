import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_spacing.dart';

class OnboardingPageContent extends StatelessWidget {
  const OnboardingPageContent({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: AppSpacing.introPagePadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              (constraints.maxHeight - AppSpacing.introPagePadding.vertical)
                  .clamp(0, double.infinity),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _EntryCard(),
            SizedBox(height: AppSpacing.xl),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(height: AppSpacing.compact),
            Text(
              description,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyLarge?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EntryCard extends StatelessWidget {
  const _EntryCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    final appColors = context.appColors;
    final textTheme = context.textTheme;
    // Decorative sample only, not real customer data or interactive controls.
    return ExcludeSemantics(
      child: Container(
        width: AppSpacing.onboardingCardWidth,
        height: AppSpacing.onboardingCardHeight,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.roomy),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.largeRadius),
          border: Border.all(color: colors.outlineVariant),
          gradient: AppGradients.onboardingCard(context),
        ),
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.cardInset),
                decoration: BoxDecoration(
                  color: appColors.cardPaperSurface,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: colors.primary,
                          size: AppSpacing.iconMedium,
                        ),
                        SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            l10n.onboardingQuickEntry,
                            maxLines: 1,
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            l10n.onboardingInstantPayment,
                            style: textTheme.labelSmall?.copyWith(
                              color: appColors.paymentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(height: AppSpacing.roomy),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.onboardingSampleCustomer,
                            style: textTheme.labelSmall,
                          ),
                        ),
                        Text(
                          l10n.onboardingSampleAmount,
                          style: textTheme.labelSmall?.copyWith(
                            color: appColors.creditColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.sm),
                    LinearProgressIndicator(
                      value: .8,
                      minHeight: AppSpacing.tight,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                top: -AppSpacing.cardInset,
                end: -AppSpacing.xs,
                child: _Badge(
                  label: l10n.onboardingSaved,
                  icon: Icons.check_circle,
                  filled: true,
                ),
              ),
              PositionedDirectional(
                bottom: -AppSpacing.cardInset,
                start: -AppSpacing.xs,
                child: _Badge(label: l10n.onboardingSeconds, icon: Icons.timer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, this.filled = false});

  final String label;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    padding: AppSpacing.badgePadding,
    decoration: BoxDecoration(
      color: filled ? context.colorScheme.primary : context.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSpacing.largeRadius),
      border: Border.all(color: context.colorScheme.outlineVariant),
      boxShadow: [AppSpacing.badgeShadow],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: AppSpacing.badgeIcon,
          color: filled
              ? context.colorScheme.onPrimary
              : context.appColors.warningColor,
        ),
        SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: filled ? context.colorScheme.onPrimary : null,
          ),
        ),
      ],
    ),
  );
}
