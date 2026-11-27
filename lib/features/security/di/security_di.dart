import 'dart:ui' show Locale;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/services/date/date_service.dart';
import '../../../core/services/loacl_storage/local_storage_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/repositories/security_repository_impl.dart';
import '../data/services/biometric_auth_service.dart';
import '../data/services/secure_storage_service.dart';
import '../domain/repositories/security_repository.dart';
import '../presentation/cubit/app_lock_cubit.dart';

void registerSecurityDependencies(GetIt sl) {
  if (!sl.isRegistered<LocalAuthentication>()) {
    sl.registerLazySingleton<LocalAuthentication>(LocalAuthentication.new);
  }
  if (!sl.isRegistered<SecureStorageService>()) {
    sl.registerLazySingleton<SecureStorageService>(
      () => SecureStorageService(sl<FlutterSecureStorage>()),
    );
  }
  if (!sl.isRegistered<BiometricAuthService>()) {
    sl.registerLazySingleton<BiometricAuthService>(
      () => BiometricAuthService(
        sl<LocalAuthentication>(),
        biometricReason: () =>
            lookupAppLocalizations(Locale(sl<LocalStorageService>().localeCode))
                .securityBiometricAction,
        recoveryReason: () =>
            lookupAppLocalizations(Locale(sl<LocalStorageService>().localeCode))
                .securityRecoveryTitle,
      ),
    );
  }
  if (!sl.isRegistered<SecurityRepository>()) {
    sl.registerLazySingleton<SecurityRepository>(
      () => SecurityRepositoryImpl(
        sl<SecureStorageService>(),
        sl<BiometricAuthService>(),
        sl<LocalStorageService>(),
        sl<DateService>(),
        sl<ErrorHandler>(),
      ),
    );
  }
  if (!sl.isRegistered<AppLockCubit>()) {
    sl.registerLazySingleton<AppLockCubit>(
      () => AppLockCubit(sl<SecurityRepository>(), sl<DateService>()),
      dispose: (cubit) => cubit.close(),
    );
  }
}
