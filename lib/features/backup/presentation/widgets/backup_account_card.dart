import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../settings/presentation/widgets/settings_icon_box.dart';

class BackupAccountCard extends StatelessWidget {
  const BackupAccountCard({super.key, this.shopName, this.email});

  final String? shopName;
  final String? email;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.settingsCardPadding,
    decoration: BoxDecoration(
      color: context.appColors.customersAccentSurface,
      borderRadius: AppSpacing.settingsOptionRadius,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsIconBox(icon: Icons.storefront_outlined),
        SizedBox(width: AppSpacing.compact),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shopName case final name? when name.isNotEmpty)
                Text(name, style: context.textTheme.titleMedium),
              if (email case final address? when address.isNotEmpty)
                Text(
                  address,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Container(
          padding: AppSpacing.badgePadding,
          decoration: BoxDecoration(
            color: context.colorScheme.primary,
            borderRadius: AppSpacing.settingsOptionRadius,
          ),
          child: Text(
            context.l10n.backupActiveAccount,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}
