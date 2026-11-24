import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/animation/app_theme_transition.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'features/backup/presentation/cubit/backup_cubit.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'features/settings/presentation/cubit/settings_state.dart';
import 'features/security/presentation/cubit/app_lock_cubit.dart';
import 'features/security/presentation/widgets/app_lock_guard.dart';
import 'l10n/generated/app_localizations.dart';

class DaftariApp extends StatefulWidget {
  const DaftariApp({
    super.key,
    this.locale = AppConstants.defaultLocale,
    this.themeMode = ThemeMode.system,
    this.router,
    this.settingsCubit,
    this.appLockCubit,
    this.authSessionCubit,
    this.backupCubit,
  });

  final Locale locale;
  final ThemeMode themeMode;
  final GoRouter? router;
  final SettingsCubit? settingsCubit;
  final AppLockCubit? appLockCubit;
  final AuthSessionCubit? authSessionCubit;
  final BackupCubit? backupCubit;

  @override
  State<DaftariApp> createState() => _DaftariAppState();
}

class _DaftariAppState extends State<DaftariApp> with WidgetsBindingObserver {
  GoRouter? _ownedRouter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.router == null) {
      _ownedRouter = AppRouter.create(
        appLock: widget.appLockCubit,
        authSessionCubit: widget.authSessionCubit,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.backupCubit?.onAppResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // An injected router is owned by its caller (the service locator in main).
    _ownedRouter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _buildSettingsApp();
    final backup = widget.backupCubit;
    if (backup != null) {
      child = BlocProvider.value(value: backup, child: child);
    }
    final auth = widget.authSessionCubit;
    if (auth != null) {
      child = BlocProvider.value(value: auth, child: child);
    }
    final lock = widget.appLockCubit;
    if (lock != null) {
      child = BlocProvider.value(value: lock, child: child);
    }
    return child;
  }

  Widget _buildSettingsApp() {
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
        builder: (context, child) {
          final content = AppThemeTransitionArea(
            child: child ?? const SizedBox.shrink(),
          );
          final lock = widget.appLockCubit;
          return lock == null
              ? content
              : AppLockGuard(lock: lock, child: content);
        },
        routerConfig: widget.router ?? (_ownedRouter ??= AppRouter.create()),
      ),
    ),
  );
}
