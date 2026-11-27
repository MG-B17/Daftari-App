import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/theme/theme_controller/theme_switcher_cubit.dart';
import '../../../../core/theme/theme_controller/theme_switcher_state.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import '../widgets/about_section.dart';
import '../widgets/language_tile.dart';
import '../widgets/settings_section_card.dart';
import '../widgets/theme_mode_selector.dart';
import '../../../auth/widgets/account_settings_section.dart';
import '../../../backup/presentation/widgets/backup_settings_section.dart';
import '../../../security/presentation/widgets/security_settings_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showStorageError(BuildContext context, Object _) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.settingsStorageError)),
        );

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<SettingsCubit, SettingsState>(
        listenWhen: (previous, current) =>
            !previous.hasError && current.hasError,
        listener: _showStorageError,
      ),
      BlocListener<ThemeSwitcherCubit, ThemeSwitcherState>(
        listenWhen: (previous, current) =>
            !previous.hasError && current.hasError,
        listener: _showStorageError,
      ),
    ],
    child: AppScaffold(
      title: context.l10n.settingsTitle,
      body: ListView(
        children: [
          const AccountSettingsSection(),
          SizedBox(height: AppSpacing.settingsSectionGap),
          const BackupSettingsSection(),
          SizedBox(height: AppSpacing.settingsSectionGap),
          SettingsSectionCard(
            title: context.l10n.settingsAppearanceTitle,
            child: const ThemeModeSelector(),
          ),
          SizedBox(height: AppSpacing.settingsSectionGap),
          SettingsSectionCard(
            title: context.l10n.settingsLanguageTitle,
            child: const LanguageTile(),
          ),
          SizedBox(height: AppSpacing.settingsSectionGap),
          const SecuritySettingsSection(),
          SizedBox(height: AppSpacing.settingsSectionGap),
          const AboutSection(),
        ],
      ),
    ),
  );
}
