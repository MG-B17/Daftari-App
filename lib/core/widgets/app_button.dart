import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_loading_indicator.dart';

enum AppButtonVariant { primary, secondary, credit, payment, outlined, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.trailingIcon,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (variant) {
      AppButtonVariant.primary => (colors.primary, colors.onPrimary),
      AppButtonVariant.secondary => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      AppButtonVariant.credit ||
      AppButtonVariant.danger => (AppColors.credit, Colors.white),
      AppButtonVariant.payment => (AppColors.payment, Colors.white),
      AppButtonVariant.outlined => (Colors.transparent, colors.primary),
    };
    final content = isLoading
        ? AppLoadingIndicator(color: colors.primary)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSpacing.icon),
                SizedBox(width: AppSpacing.sm),
              ],
              Flexible(child: Text(label, textAlign: TextAlign.center)),
              if (trailingIcon != null) ...[
                SizedBox(width: AppSpacing.sm),
                Icon(trailingIcon, size: AppSpacing.icon),
              ],
            ],
          );
    final callback = isLoading ? null : onPressed;
    final button = variant == AppButtonVariant.outlined
        ? OutlinedButton(onPressed: callback, child: content)
        : FilledButton(
            onPressed: callback,
            style: FilledButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
            ),
            child: content,
          );
    return SizedBox(width: fullWidth ? double.infinity : null, child: button);
  }
}
