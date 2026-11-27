import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/animation/app_theme_transition.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/theme/theme_controller/theme_switcher_cubit.dart';
import '../../../../core/theme/theme_controller/theme_switcher_state.dart';

enum _ThemeOption {
  light(ThemeMode.light, Icons.light_mode_outlined),
  dark(ThemeMode.dark, Icons.dark_mode_outlined),
  system(ThemeMode.system, Icons.brightness_auto_outlined);

  const _ThemeOption(this.mode, this.icon);

  final ThemeMode mode;
  final IconData icon;
}

class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ThemeSwitcherCubit, ThemeSwitcherState>(
        buildWhen: (previous, current) =>
            previous.themeMode != current.themeMode,
        builder: (context, state) {
          final l10n = context.l10n;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final option in _ThemeOption.values) ...[
                      if (option != _ThemeOption.values.first)
                        SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppThemeSwitcher(
                          builder: (context, transition) => _ThemeOptionCard(
                            option: option,
                            label: switch (option) {
                              _ThemeOption.light => l10n.settingsThemeLight,
                              _ThemeOption.dark => l10n.settingsThemeDark,
                              _ThemeOption.system => l10n.settingsThemeSystem,
                            },
                            isSelected: state.themeMode == option.mode,
                            onTap: () {
                              if (state.themeMode == option.mode) return;
                              if (!MediaQuery.disableAnimationsOf(context)) {
                                transition(option.mode);
                              }
                              unawaited(
                                context.read<ThemeSwitcherCubit>().setThemeMode(
                                  option.mode,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.compact),
              Text(
                l10n.settingsAppearanceCaption,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      );
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.option,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final _ThemeOption option;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final foreground = isSelected ? colors.onPrimary : colors.onSurface;
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? colors.primary : context.appColors.cardPaperSurface,
        borderRadius: AppSpacing.settingsOptionRadius,
        child: InkWell(
          key: ValueKey('theme-${option.name}'),
          onTap: onTap,
          borderRadius: AppSpacing.settingsOptionRadius,
          child: Container(
            constraints: BoxConstraints(
              minHeight: AppSpacing.settingsOptionHeight,
            ),
            padding: AppSpacing.settingsOptionPadding,
            decoration: BoxDecoration(
              borderRadius: AppSpacing.settingsOptionRadius,
              border: Border.all(
                color: isSelected ? colors.primary : colors.outline,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  option.icon,
                  size: AppSpacing.iconMedium,
                  color: foreground,
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: foreground,
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
