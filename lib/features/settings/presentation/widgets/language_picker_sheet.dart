import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';
import 'settings_icon_box.dart';

class LanguagePickerSheet extends StatelessWidget {
  const LanguagePickerSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appColors.paperBackground,
    shape: RoundedRectangleBorder(borderRadius: AppSpacing.settingsSheetRadius),
    builder: (_) => const LanguagePickerSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: AppSpacing.settingsSheetPadding,
        child: BlocBuilder<SettingsCubit, SettingsState>(
          buildWhen: (previous, current) =>
              previous.localeCode != current.localeCode,
          builder: (context, state) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: AppSpacing.settingsSheetHandleWidth,
                  height: AppSpacing.settingsSheetHandleHeight,
                  decoration: BoxDecoration(
                    color: context.colorScheme.outline,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.settingsSheetHandleHeight,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const SettingsIconBox(icon: Icons.menu_book_rounded),
                  SizedBox(width: AppSpacing.compact),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsLanguagePickerTitle,
                          style: context.textTheme.titleLarge,
                        ),
                        Text(
                          l10n.settingsLanguagePickerSubtitle,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.lg),
              _LanguageOption(
                languageCode: 'ar',
                title: l10n.settingsLanguageArabic,
                subtitle: l10n.settingsLanguageArabicDescription,
                badge: l10n.settingsLanguageBadgeArabic,
                isSelected: state.isArabic,
              ),
              SizedBox(height: AppSpacing.sm),
              _LanguageOption(
                languageCode: 'en',
                title: l10n.settingsLanguageEnglish,
                subtitle: l10n.settingsLanguageEnglishDescription,
                badge: l10n.settingsLanguageBadgeEnglish,
                isSelected: !state.isArabic,
              ),
              SizedBox(height: AppSpacing.lg),
              Container(
                padding: AppSpacing.controlPadding,
                decoration: BoxDecoration(
                  color: context.appColors.cardPaperSurface,
                  borderRadius: AppSpacing.settingsOptionRadius,
                  border: Border.all(color: context.colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: AppSpacing.iconSmall,
                      color: context.appColors.warningColor,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.settingsLanguageHint,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.languageCode,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.isSelected,
  });

  final String languageCode;
  final String title;
  final String subtitle;
  final String badge;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: context.appColors.cardPaperSurface,
        borderRadius: AppSpacing.settingsOptionRadius,
        child: InkWell(
          key: ValueKey('language-option-$languageCode'),
          borderRadius: AppSpacing.settingsOptionRadius,
          onTap: () {
            if (!isSelected) {
              unawaited(
                context.read<SettingsCubit>().setLocaleCode(languageCode),
              );
            }
            Navigator.of(context).pop();
          },
          child: Container(
            padding: AppSpacing.settingsOptionPadding,
            decoration: BoxDecoration(
              borderRadius: AppSpacing.settingsOptionRadius,
              border: Border.all(
                color: isSelected ? colors.primary : colors.outline,
                width: isSelected
                    ? AppSpacing.selectedStroke
                    : AppSpacing.hairline,
              ),
            ),
            child: Row(
              children: [
                _SelectionIndicator(isSelected: isSelected),
                SizedBox(width: AppSpacing.compact),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.textTheme.titleMedium),
                      Text(
                        subtitle,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Container(
                  width: AppSpacing.settingsBadgeSize,
                  height: AppSpacing.settingsBadgeSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: AppSpacing.settingsOptionRadius,
                  ),
                  child: Text(
                    badge,
                    style: context.textTheme.labelLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      width: AppSpacing.settingsRadioSize,
      height: AppSpacing.settingsRadioSize,
      decoration: BoxDecoration(
        color: isSelected ? colors.primary : context.appColors.cardPaperSurface,
        shape: BoxShape.circle,
        border: Border.all(color: isSelected ? colors.primary : colors.outline),
      ),
      child: isSelected
          ? Icon(
              Icons.check_rounded,
              size: AppSpacing.badgeIcon,
              color: colors.onPrimary,
            )
          : null,
    );
  }
}
