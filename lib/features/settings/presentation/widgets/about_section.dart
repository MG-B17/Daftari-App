import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import 'settings_icon_box.dart';
import 'settings_section_card.dart';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsSectionCard(
      title: l10n.settingsAboutTitle,
      child: Wrap(
        spacing: AppSpacing.compact,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SettingsIconBox(icon: Icons.info_outline_rounded),
              SizedBox(width: AppSpacing.compact),
              Flexible(
                child: Text(
                  l10n.settingsVersionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          Container(
            padding: AppSpacing.badgePadding,
            decoration: BoxDecoration(
              color: context.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            ),
            child: Text(
              '${AppConstants.appVersion} (${l10n.settingsVersionStable})',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
