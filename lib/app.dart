import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/animation/app_theme_transition.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'features/settings/presentation/cubit/settings_state.dart';
import 'l10n/generated/app_localizations.dart';

class DaftariApp extends StatefulWidget {
  const DaftariApp({
    super.key,
    this.locale = AppConstants.defaultLocale,
    this.themeMode = ThemeMode.system,
    this.router,
    this.settingsCubit,
  });

  final Locale locale;
  final ThemeMode themeMode;
  final GoRouter? router;
  final SettingsCubit? settingsCubit;

  @override
  State<DaftariApp> createState() => _DaftariAppState();
}

class _DaftariAppState extends State<DaftariApp> {
  GoRouter? _ownedRouter;

  @override
  void initState() {
    super.initState();
    if (widget.router == null) _ownedRouter = AppRouter.create();
  }

  @override
  void dispose() {
    // An injected router is owned by its caller (the service locator in main).
    _ownedRouter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsCubit = widget.settingsCubit;
    if (settingsCubit == null) {
      return _buildApp(locale: widget.locale, themeMode: widget.themeMode);
    }
    return BlocProvider.value(
      value: settingsCubit,
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) =>
            _buildApp(locale: state.locale, themeMode: state.themeMode),
      ),
    );
  }

  Widget _buildApp({
    required Locale locale,
    required ThemeMode themeMode,
  }) => ScreenUtilInit(
    designSize: AppConstants.designSize,
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => AppThemeTransitionProvider(
      initialTheme:
          themeMode == ThemeMode.dark ||
              (themeMode == ThemeMode.system &&
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark)
          ? AppTheme.dark
          : AppTheme.light,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppConstants.supportedLocales,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        builder: (context, child) =>
            AppThemeTransitionArea(child: child ?? const SizedBox.shrink()),
        routerConfig: widget.router ?? (_ownedRouter ??= AppRouter.create()),
      ),
    ),
  );
}
