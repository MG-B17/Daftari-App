import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'app_button.dart';
import 'app_empty_state.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key, this.title, this.message, this.onRetry});

  final String? title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppEmptyState(
      icon: Icons.error_outline,
      title: title ?? l10n.errorTitle,
      message: message ?? l10n.errorMessage,
      action: onRetry == null
          ? null
          : AppButton(label: l10n.retry, onPressed: onRetry),
    );
  }
}
