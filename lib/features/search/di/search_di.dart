import 'package:get_it/get_it.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/error_handler.dart';
import '../data/repositories/search_repository_impl.dart';
import '../domain/repositories/search_repository.dart';
import '../domain/usecases/watch_search_customers_usecase.dart';
import '../presentation/cubit/search_cubit.dart';

void registerSearchDependencies(GetIt sl) {
  if (!sl.isRegistered<SearchRepository>()) {
    sl.registerLazySingleton<SearchRepository>(
      () => SearchRepositoryImpl(sl<CustomerDao>(), sl<ErrorHandler>()),
    );
  }
  if (!sl.isRegistered<WatchSearchCustomersUseCase>()) {
    sl.registerLazySingleton<WatchSearchCustomersUseCase>(
      () => WatchSearchCustomersUseCase(sl<SearchRepository>()),
    );
  }
  if (!sl.isRegistered<SearchCubit>()) {
    sl.registerFactory<SearchCubit>(
      () => SearchCubit(sl<WatchSearchCustomersUseCase>()),
    );
  }
}
