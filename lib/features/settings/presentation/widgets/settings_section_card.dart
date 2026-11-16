import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: AppSpacing.settingsSectionTitlePadding,
        child: Text(title, style: context.textTheme.titleMedium),
      ),
      Container(
        width: double.infinity,
        padding: AppSpacing.settingsCardPadding,
        decoration: BoxDecoration(
          color: context.appColors.cardPaperSurface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: context.colorScheme.outline),
        ),
        child: child,
      ),
    ],
  );
}
