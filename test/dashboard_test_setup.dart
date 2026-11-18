import 'package:daftariapp/core/di/service_locator.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/services/date_service.dart';
import 'package:daftariapp/features/dashboard/domain/entities/dashboard_summary_entity.dart';
import 'package:daftariapp/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:daftariapp/features/dashboard/domain/usecases/watch_dashboard_summary_usecase.dart';
import 'package:daftariapp/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:fpdart/fpdart.dart';

class _EmptyDashboardRepository implements DashboardRepository {
  const _EmptyDashboardRepository();

  @override
  Stream<Either<AppFailure, DashboardSummaryEntity>> watchDashboardSummary() =>
      Stream.value(const Right(DashboardSummaryEntity.empty()));
}

Future<void> setupDashboardTests() async {
  await sl.reset();
  sl.registerFactory(
    () => DashboardCubit(
      const WatchDashboardSummaryUseCase(_EmptyDashboardRepository()),
      SystemDateService(),
    ),
  );
}
