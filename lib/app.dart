import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';

class DaftariApp extends StatefulWidget {
  const DaftariApp({
    super.key,
    this.locale = AppConstants.defaultLocale,
    this.themeMode = ThemeMode.system,
    this.router,
  });

  final Locale locale;
  final ThemeMode themeMode;
  final GoRouter? router;

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
  Widget build(BuildContext context) => ScreenUtilInit(
    designSize: AppConstants.designSize,
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      locale: widget.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppConstants.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: widget.themeMode,
      routerConfig: widget.router ?? (_ownedRouter ??= AppRouter.create()),
    ),
  );
}
