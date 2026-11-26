import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_color_scheme.dart';
import 'app_button.dart';
import 'app_feedback_dialog.dart';

class AppSuccessDialog extends StatelessWidget {
  const AppSuccessDialog({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.assetPath = defaultAssetPath,
    this.semanticsLabel,
    this.onDismiss,
  });

  static const defaultAssetPath = 'assets/lottie/success animation.json';
  static const debtPaidAssetPath =
      'assets/lottie/Debt_Paid_Status_Animation_v1.json';
  static const transactionAddedAssetPath =
      'assets/lottie/Transaction_Added_Ledger_Entry_v1.json';

  final String title;
  final String? message;
  final String? actionLabel;
  final String assetPath;
  final String? semanticsLabel;
  final VoidCallback? onDismiss;

  static Future<void> show(
    BuildContext context, {
    required String title,
    String? message,
    String? actionLabel,
    String assetPath = defaultAssetPath,
    String? semanticsLabel,
    bool barrierDismissible = true,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => AppSuccessDialog(
      title: title,
      message: message,
      actionLabel: actionLabel,
      assetPath: assetPath,
      semanticsLabel: semanticsLabel,
      onDismiss: () => Navigator.of(dialogContext).pop(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final appColors = theme.extension<AppColorScheme>();
    final l10n = AppLocalizations.of(context);
    return AppFeedbackDialog(
      title: title,
      message: message,
      assetPath: assetPath,
      animationSemanticsLabel:
          semanticsLabel ?? l10n?.feedbackSuccessLabel ?? 'Success',
      staticIcon: Icons.check_rounded,
      staticIconColor: appColors?.paymentColor ?? colors.primary,
      staticBadgeColor: appColors?.paymentSurface ?? colors.primaryContainer,
      actions: [
        AppButton(
          label: actionLabel ?? l10n?.ok ?? 'OK',
          fullWidth: true,
          onPressed: onDismiss ?? () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
