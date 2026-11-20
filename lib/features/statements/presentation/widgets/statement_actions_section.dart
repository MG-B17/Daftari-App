import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class StatementActionsSection extends StatelessWidget {
  const StatementActionsSection({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        key: const ValueKey('statement-whatsapp'),
        // Mock data must never be sent as a real customer's statement.
        onPressed: null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: context.appColors.whatsappColor,
          disabledForegroundColor: context.appColors.onWhatsappColor,
          minimumSize: Size.fromHeight(AppSpacing.statementActionHeight),
        ),
        icon: const Icon(Icons.chat_outlined),
        label: Text(context.l10n.statementWhatsApp),
      ),
      SizedBox(height: AppSpacing.sm),
      FilledButton.tonalIcon(
        key: const ValueKey('statement-copy'),
        onPressed: null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: context.appColors.customersAccentSurface,
          disabledForegroundColor: context.colorScheme.onSurface,
          minimumSize: Size.fromHeight(AppSpacing.statementActionHeight),
        ),
        icon: const Icon(Icons.copy_outlined),
        label: Text(context.l10n.statementCopy),
      ),
      SizedBox(height: AppSpacing.compact),
      Text(
        context.l10n.statementShareHint,
        textAlign: TextAlign.center,
        style: context.textTheme.bodySmall,
      ),
      SizedBox(height: AppSpacing.md),
    ],
  );
}
