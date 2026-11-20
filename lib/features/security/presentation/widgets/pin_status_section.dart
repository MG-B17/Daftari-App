import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import 'pin_dots_indicator.dart';

/// Dots, helper text, progress, cooldown and error feedback for the PIN flow.
class PinStatusSection extends StatelessWidget {
  const PinStatusSection({
    super.key,
    required this.count,
    required this.busy,
    required this.cooldownSeconds,
    this.message,
  });

  final int count;
  final bool busy;
  final int cooldownSeconds;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          PinDotsIndicator(count: count),
          SizedBox(height: AppSpacing.md),
          Text(l10n.securityPinHelper, style: context.textTheme.bodySmall),
          if (busy) ...[
            SizedBox(height: AppSpacing.md),
            const CircularProgressIndicator(),
            Text(l10n.loading),
          ],
          if (cooldownSeconds > 0) Text(l10n.securityCooldown(cooldownSeconds)),
          if (message != null)
            Semantics(
              liveRegion: true,
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
