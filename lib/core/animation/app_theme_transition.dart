import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppThemeTransitionProvider extends StatelessWidget {
  const AppThemeTransitionProvider({
    super.key,
    required this.initialTheme,
    required this.child,
  });

  final ThemeData initialTheme;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ThemeProvider(initTheme: initialTheme, child: child);
}

class AppThemeTransitionArea extends StatelessWidget {
  const AppThemeTransitionArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ThemeSwitchingArea(
      child: Theme(data: theme, child: child),
    );
  }
}

class AppThemeSwitcher extends StatelessWidget {
  const AppThemeSwitcher({super.key, required this.builder});

  final Widget Function(
    BuildContext context,
    void Function(ThemeMode) transition,
  )
  builder;

  @override
  Widget build(BuildContext context) => ThemeSwitcher.switcher(
    builder: (context, switcher) => builder(context, (mode) {
      switcher.changeTheme(
        theme: AppTheme.resolve(mode, MediaQuery.platformBrightnessOf(context)),
      );
    }),
  );
}
