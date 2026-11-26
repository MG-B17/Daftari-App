import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_spacing.dart';

class AppFeedbackDialog extends StatelessWidget {
  const AppFeedbackDialog({
    super.key,
    required this.title,
    required this.assetPath,
    required this.animationSemanticsLabel,
    required this.staticIcon,
    required this.staticIconColor,
    required this.staticBadgeColor,
    required this.actions,
    this.message,
  });

  final String title;
  final String? message;
  final String assetPath;
  final String animationSemanticsLabel;
  final IconData staticIcon;
  final Color staticIconColor;
  final Color staticBadgeColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final visualSize = AppSpacing.feedbackDialogVisualSize;
    final hasMessage = message != null && message!.isNotEmpty;

    final staticEquivalent = _StaticFeedbackBadge(
      icon: staticIcon,
      iconColor: staticIconColor,
      badgeColor: staticBadgeColor,
    );

    final visual = SizedBox.square(
      dimension: visualSize,
      child: reduceMotion
          ? staticEquivalent
          : Lottie.asset(
              assetPath,
              width: visualSize,
              height: visualSize,
              fit: BoxFit.contain,
              repeat: false,
              errorBuilder: (_, _, _) => staticEquivalent,
            ),
    );

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppSpacing.feedbackDialogMaxWidth,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Semantics(
                  label: animationSemanticsLabel,
                  image: true,
                  excludeSemantics: true,
                  child: visual,
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (hasMessage) ...[
                SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: AppSpacing.lg),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) SizedBox(height: AppSpacing.sm),
                actions[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StaticFeedbackBadge extends StatelessWidget {
  const _StaticFeedbackBadge({
    required this.icon,
    required this.iconColor,
    required this.badgeColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: AppSpacing.feedbackDialogBadgeSize,
      height: AppSpacing.feedbackDialogBadgeSize,
      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: AppSpacing.feedbackDialogIconSize,
        color: iconColor,
      ),
    ),
  );
}
