import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_color_scheme.dart';
import 'app_button.dart';
import 'app_feedback_dialog.dart';

class AppErrorDialog extends StatelessWidget {
  const AppErrorDialog({
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.retryLabel,
    this.assetPath = defaultAssetPath,
    this.semanticsLabel,
    this.onRetry,
    this.onDismiss,
  });

  static const defaultAssetPath = 'assets/lottie/ERROR Animation.json';

  final String? title;
  final String? message;
  final String? actionLabel;
  final String? retryLabel;
  final String assetPath;
  final String? semanticsLabel;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  /// Returns `true` when the user selects retry, or `false` when dismissed.
  static Future<bool> show(
    BuildContext context, {
    String? title,
    String? message,
    String? actionLabel,
    String? retryLabel,
    bool showRetry = false,
    String assetPath = defaultAssetPath,
    String? semanticsLabel,
    bool barrierDismissible = true,
  }) async =>
      await showDialog<bool>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (dialogContext) => AppErrorDialog(
          title: title,
          message: message,
          actionLabel: actionLabel,
          retryLabel: retryLabel,
          assetPath: assetPath,
          semanticsLabel: semanticsLabel,
          onRetry: showRetry
              ? () => Navigator.of(dialogContext).pop(true)
              : null,
          onDismiss: () => Navigator.of(dialogContext).pop(false),
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = theme.extension<AppColorScheme>();
    final l10n = AppLocalizations.of(context);
    final dismiss = onDismiss ?? () => Navigator.of(context).pop(false);
    return AppFeedbackDialog(
      title: title ?? l10n?.errorTitle ?? 'Something went wrong',
      message: message ?? l10n?.errorMessage ?? 'Please try again.',
      assetPath: assetPath,
      animationSemanticsLabel:
          semanticsLabel ?? l10n?.feedbackErrorLabel ?? 'Error',
      staticIcon: Icons.error_outline_rounded,
      staticIconColor: appColors?.creditColor ?? colors.error,
      staticBadgeColor: appColors?.creditSurface ?? colors.errorContainer,
      actions: [
        if (onRetry != null) ...[
          AppButton(
            label: retryLabel ?? l10n?.retry ?? 'Retry',
            fullWidth: true,
            onPressed: onRetry,
          ),
          AppButton(
            label: actionLabel ?? l10n?.ok ?? 'OK',
            variant: AppButtonVariant.outlined,
            fullWidth: true,
            onPressed: dismiss,
          ),
        ] else
          AppButton(
            label: actionLabel ?? l10n?.ok ?? 'OK',
            fullWidth: true,
            onPressed: dismiss,
          ),
      ],
    );
  }
}
