import 'package:get_it/get_it.dart';

import '../../../core/services/loacl_storage/local_storage_service.dart';
import '../presentation/cubit/onboarding_cubit.dart';

void registerOnboardingDependencies(GetIt sl) {
  if (!sl.isRegistered<OnboardingCubit>()) {
    sl.registerFactory<OnboardingCubit>(
      () => OnboardingCubit(sl<LocalStorageService>()),
    );
  }
}
