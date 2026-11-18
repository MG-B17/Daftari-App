import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/dashboard_summary_entity.dart';
import '../repositories/dashboard_repository.dart';

class WatchDashboardSummaryUseCase {
  const WatchDashboardSummaryUseCase(this._repository);
  final DashboardRepository _repository;

  Stream<Either<AppFailure, DashboardSummaryEntity>> call() =>
      _repository.watchDashboardSummary();
}
