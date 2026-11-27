import 'package:get_it/get_it.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/services/date/date_service.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/usecases/watch_dashboard_summary_usecase.dart';
import '../presentation/cubit/dashboard_cubit.dart';

void registerDashboardDependencies(GetIt sl) {
  if (!sl.isRegistered<DashboardRepository>()) {
    sl.registerLazySingleton<DashboardRepository>(
      () => DashboardRepositoryImpl(
        sl<CustomerDao>(),
        sl<TransactionDao>(),
        sl<ErrorHandler>(),
        sl<DateService>(),
      ),
    );
  }
  if (!sl.isRegistered<WatchDashboardSummaryUseCase>()) {
    sl.registerLazySingleton<WatchDashboardSummaryUseCase>(
      () => WatchDashboardSummaryUseCase(sl<DashboardRepository>()),
    );
  }
  if (!sl.isRegistered<DashboardCubit>()) {
    sl.registerFactory<DashboardCubit>(
      () =>
          DashboardCubit(sl<WatchDashboardSummaryUseCase>(), sl<DateService>()),
    );
  }
}
