import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'app_button.dart';

class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final String? confirmLabel;
  final bool isDestructive;

  /// Dismissal and cancellation both mean the operation was not confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    bool isDestructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AppConfirmationDialog(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          isDestructive: isDestructive,
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        AppButton(
          label: confirmLabel ?? l10n.confirm,
          variant: isDestructive
              ? AppButtonVariant.danger
              : AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
