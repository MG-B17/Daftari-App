import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../entities/dashboard_summary_entity.dart';

abstract interface class DashboardRepository {
  /// Emits a fresh summary whenever active customers or transactions change,
  /// and a failure without closing the stream.
  Stream<Either<AppFailure, DashboardSummaryEntity>> watchDashboardSummary();
}
