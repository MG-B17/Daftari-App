import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    required this.onClear,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      4,
      (row) => Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: List.generate(3, (column) {
            final index = row * 3 + column;
            final digit = index == 10 ? '0' : '${index + 1}';
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: SizedBox(
                  height: AppSpacing.pinKeySize,
                  child: index == 9
                      ? TextButton(
                          onPressed: enabled ? onClear : null,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor:
                                context.colorScheme.onSurfaceVariant,
                            textStyle: context.textTheme.bodySmall,
                          ),
                          child: Text(
                            context.l10n.securityClearAll,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : index == 11
                      ? IconButton(
                          tooltip: context.l10n.securityDeleteDigit,
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: AppSpacing.borderRadius,
                              side: BorderSide(
                                color: context.colorScheme.outline,
                              ),
                            ),
                            backgroundColor:
                                context.appColors.lockDeleteSurface,
                            foregroundColor:
                                context.appColors.lockDeleteForeground,
                          ),
                          onPressed: enabled ? onDelete : null,
                          icon: const Icon(Icons.backspace_rounded),
                        )
                      : FilledButton(
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppSpacing.borderRadius,
                            ),
                            backgroundColor: context.appColors.lockKeySurface,
                            foregroundColor: context.colorScheme.onSurface,
                            side: BorderSide(
                              color: context.colorScheme.outline,
                            ),
                            textStyle: context.textTheme.headlineSmall,
                          ),
                          onPressed: enabled ? () => onDigit(digit) : null,
                          child: Text(digit),
                        ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}
