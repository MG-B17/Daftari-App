import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/date_service.dart';
import '../entities/backup_schedule.dart';
import '../policies/backup_schedule_policy.dart';
import '../repositories/backup_local_store.dart';

/// Atomically selects the first backup schedule or replaces the active schedule
/// against the latest persisted state while preserving the last confirmed
/// timestamp.
class UpdateBackupScheduleUseCase {
  const UpdateBackupScheduleUseCase({
    required this._localStore,
    required this._dateService,
  });

  final BackupLocalStore _localStore;
  final DateService _dateService;

  Future<Either<AppFailure, BackupScheduleState>> call(
    BackupSchedule schedule,
  ) => _localStore.updateScheduleState(
    (latest, hasPendingChanges) => BackupSchedulePolicy.selectSchedule(
      latest,
      schedule,
      now: _dateService.now(),
      hasPendingChanges: hasPendingChanges,
    ),
  );
}
