import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'core/services/app_logger.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'features/security/presentation/cubit/app_lock_cubit.dart';
import 'firebase_options.dart';

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

  runApp(
    DaftariApp(
      router: sl<GoRouter>(),
      settingsCubit: sl<SettingsCubit>(),
      appLockCubit: sl<AppLockCubit>(),
    ),
  );
}
