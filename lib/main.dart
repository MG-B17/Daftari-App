import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show PlatformDispatcher, kDebugMode, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/services/app_logger.dart';
import 'core/theme/theme_switcher_cubit.dart';
import 'features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'features/backup/data/services/backup_background_worker.dart';
import 'features/backup/presentation/cubit/backup_cubit.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'features/security/presentation/cubit/app_lock_cubit.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> backupWorkerMain(List<String> args) =>
    runBackupBackgroundWorker(args);

Future<void> main({bool useMarionetteBinding = false}) async {
  if (kDebugMode && useMarionetteBinding) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await configureDependencies();
  final backupCubit = sl<BackupCubit>();
  startDaftariApp(
    logger: sl<AppLogger>(),
    backupCubit: backupCubit,
    app: DaftariApp(
      router: sl<GoRouter>(),
      settingsCubit: sl<SettingsCubit>(),
      themeSwitcherCubit: sl<ThemeSwitcherCubit>(),
      appLockCubit: sl<AppLockCubit>(),
      authSessionCubit: sl<AuthSessionCubit>(),
      backupCubit: backupCubit,
    ),
  );
}

/// blocking the first frame, and mounts [app].
@visibleForTesting
void startDaftariApp({
  required AppLogger logger,
  required BackupCubit backupCubit,
  required Widget app,
  void Function(Widget) runAppCallback = runApp,
}) {
  FlutterError.onError = (details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
    unawaited(logger.recordError(details.exception, fatal: true));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Uncaught platform error: $error\n$stack');
    }
    unawaited(logger.recordError(error, fatal: true));
    return true;
  };

  unawaited(backupCubit.initialize());
  runAppCallback(app);
}
