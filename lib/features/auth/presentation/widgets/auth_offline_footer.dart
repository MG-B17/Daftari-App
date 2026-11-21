import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class AuthOfflineFooter extends StatelessWidget {
  const AuthOfflineFooter({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextButton(
        onPressed: onContinue,
        child: Text(
          context.l10n.authContinueOffline,
          textAlign: TextAlign.center,
        ),
      ),
      Text(
        context.l10n.authContinueOfflineHint,
        textAlign: TextAlign.center,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      SizedBox(height: AppSpacing.sm),
    ],
  );
}
