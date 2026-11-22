import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/app_confirmation_dialog.dart';

abstract final class LedgerLinkConfirmationDialog {
  static Future<bool> show(BuildContext context) {
    final l10n = context.l10n;
    return AppConfirmationDialog.show(
      context,
      title: l10n.authLinkDialogTitle,
      message: l10n.authLinkDialogMessage,
      confirmLabel: l10n.authLinkDialogConfirm,
    );
  }
}
