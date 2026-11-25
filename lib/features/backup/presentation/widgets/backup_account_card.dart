import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../settings/presentation/widgets/settings_icon_box.dart';

class BackupAccountCard extends StatelessWidget {
  const BackupAccountCard({super.key, this.shopName, this.email});

  final String? shopName;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final trimmedShop = shopName?.trim();
    final trimmedEmail = email?.trim();
    final hasAccount =
        (trimmedShop != null && trimmedShop.isNotEmpty) ||
        (trimmedEmail != null && trimmedEmail.isNotEmpty);
    final captionStyle = context.textTheme.bodySmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    return Container(
      width: double.infinity,
      padding: AppSpacing.settingsCardPadding,
      decoration: BoxDecoration(
        color: context.appColors.customersAccentSurface,
        borderRadius: AppSpacing.settingsOptionRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsIconBox(
            icon: hasAccount
                ? Icons.storefront_outlined
                : Icons.person_outline_rounded,
          ),
          SizedBox(width: AppSpacing.compact),
          Expanded(
            child: hasAccount
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (trimmedShop != null && trimmedShop.isNotEmpty)
                        Text(trimmedShop, style: context.textTheme.titleMedium),
                      if (trimmedEmail != null && trimmedEmail.isNotEmpty)
                        Text(trimmedEmail, style: captionStyle),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.backupAccountSignedOutTitle,
                        style: context.textTheme.titleMedium,
                      ),
                      Text(
                        context.l10n.backupAccountSignedOutSubtitle,
                        style: captionStyle,
                      ),
                    ],
                  ),
          ),
          if (hasAccount) ...[
            SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Container(
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
            ),
          ],
        ],
      ),
    );
  }
}
