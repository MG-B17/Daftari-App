import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class SettingsIconBox extends StatelessWidget {
  const SettingsIconBox({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: AppSpacing.settingsIconBox,
    height: AppSpacing.settingsIconBox,
    decoration: BoxDecoration(
      color: context.colorScheme.primaryContainer,
      borderRadius: AppSpacing.settingsOptionRadius,
    ),
    child: Icon(
      icon,
      size: AppSpacing.iconMedium,
      color: context.colorScheme.onPrimaryContainer,
    ),
  );
}
