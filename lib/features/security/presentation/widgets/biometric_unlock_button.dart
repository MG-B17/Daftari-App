import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class BiometricUnlockButton extends StatelessWidget {
  const BiometricUnlockButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      backgroundColor: context.appColors.lockKeySurface,
      foregroundColor: context.colorScheme.primary,
      shape: const StadiumBorder(),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.compact,
      ),
      side: BorderSide(color: context.colorScheme.outline),
    ),
    onPressed: onPressed,
    icon: const Icon(Icons.fingerprint),
    label: Text(context.l10n.securityBiometricAction),
  );
}
