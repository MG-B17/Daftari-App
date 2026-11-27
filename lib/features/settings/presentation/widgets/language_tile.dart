import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import 'language_picker_sheet.dart';
import 'settings_icon_box.dart';

class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<SettingsCubit, SettingsState>(
        buildWhen: (previous, current) =>
            previous.localeCode != current.localeCode,
        builder: (context, state) {
          final l10n = context.l10n;
          return Material(
            color: context.appColors.cardPaperSurface,
            borderRadius: AppSpacing.settingsOptionRadius,
            child: InkWell(
              key: const ValueKey('language-tile'),
              borderRadius: AppSpacing.settingsOptionRadius,
              onTap: () => LanguagePickerSheet.show(context),
              child: Padding(
                padding: AppSpacing.settingsOptionPadding,
                child: Row(
                  children: [
                    const SettingsIconBox(icon: Icons.language_rounded),
                    SizedBox(width: AppSpacing.compact),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.isArabic
                                ? l10n.settingsLanguageArabic
                                : l10n.settingsLanguageEnglish,
                            style: context.textTheme.titleMedium,
                          ),
                          Text(
                            l10n.settingsLanguageChange,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      size: AppSpacing.iconSmall,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
