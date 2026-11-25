import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/services/app_logger.dart';
import 'features/auth/session/presentation/cubit/auth_session_cubit.dart';
import 'features/backup/data/services/backup_background_worker.dart';
import 'features/backup/presentation/cubit/backup_cubit.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'features/security/presentation/cubit/app_lock_cubit.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> backupWorkerMain(List<String> args) =>
    runBackupBackgroundWorker(args);

Future<void> main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await configureDependencies();
  final logger = sl<AppLogger>();
  FlutterError.onError = (details) {
    unawaited(logger.recordError(details.exception, fatal: true));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(logger.recordError(error, fatal: true));
    return true;
  };

  final backupCubit = sl<BackupCubit>();
  unawaited(backupCubit.initialize());

  runApp(
    DaftariApp(
      router: sl<GoRouter>(),
      settingsCubit: sl<SettingsCubit>(),
      appLockCubit: sl<AppLockCubit>(),
      authSessionCubit: sl<AuthSessionCubit>(),
      backupCubit: backupCubit,
    ),
  );
}
