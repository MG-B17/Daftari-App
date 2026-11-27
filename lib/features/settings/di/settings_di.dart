import 'package:get_it/get_it.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/services/loacl_storage/local_storage_service.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/usecases/change_language_usecase.dart';
import '../domain/usecases/get_settings_usecase.dart';
import '../presentation/cubit/settings_cubit.dart';

void registerSettingsDependencies(GetIt sl) {
  if (!sl.isRegistered<SettingsRepository>()) {
    sl.registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(sl<LocalStorageService>()),
    );
  }
  if (!sl.isRegistered<GetSettingsUseCase>()) {
    sl.registerLazySingleton<GetSettingsUseCase>(
      () => GetSettingsUseCase(sl<SettingsRepository>()),
    );
  }
  if (!sl.isRegistered<ChangeLanguageUseCase>()) {
    sl.registerLazySingleton<ChangeLanguageUseCase>(
      () => ChangeLanguageUseCase(sl<SettingsRepository>()),
    );
  }
  if (!sl.isRegistered<SettingsCubit>()) {
    sl.registerLazySingleton<SettingsCubit>(
      () => SettingsCubit(
        sl<GetSettingsUseCase>(),
        sl<ChangeLanguageUseCase>(),
        sl<ErrorHandler>(),
      ),
      dispose: (cubit) => cubit.close(),
    );
  }
}
