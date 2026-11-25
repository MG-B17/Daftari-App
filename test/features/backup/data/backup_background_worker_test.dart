import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/backup/data/services/backup_background_worker.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_schedule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  group('reconcileBackupWorkerSuccessor', () {
    final persistedSchedule = BackupScheduleState(
      schedule: BackupSchedule.daily,
      lastConfirmedAt: DateTime.utc(2026, 11, 24, 10),
      nextDueAt: DateTime.utc(2026, 11, 25, 10),
    );

    test('P12-23: retries after a transient schedule read error and enqueues one successor', () async {
      var readCalls = 0;
      final syncedSchedules = <BackupScheduleState>[];
      var cancelCalls = 0;

      await reconcileBackupWorkerSuccessor(
        readScheduleState: () async {
          readCalls++;
          if (readCalls == 1) {
            return const Left(AppFailure(AppErrorCode.database));
          }
          return Right(persistedSchedule);
        },
        syncSchedule: (schedule, _) async {
          syncedSchedules.add(schedule);
        },
        cancelSchedule: () async {
          cancelCalls++;
        },
        now: () => DateTime.utc(2026, 11, 24, 10, 1),
        retryDelay: Duration.zero,
      );

      expect(readCalls, 3);
      expect(syncedSchedules, [persistedSchedule]);
      expect(cancelCalls, 0);
    });

    test('P12-23: throws when all schedule reads fail before any successor is enqueued', () async {
      var readCalls = 0;
      var syncCalls = 0;

      await expectLater(
        reconcileBackupWorkerSuccessor(
          readScheduleState: () async {
            readCalls++;
            return const Left(AppFailure(AppErrorCode.database));
          },
          syncSchedule: (_, _) async {
            syncCalls++;
          },
          cancelSchedule: () async {},
          now: () => DateTime.utc(2026, 11, 24, 10, 1),
          retryDelay: Duration.zero,
        ),
        throwsStateError,
      );

      expect(readCalls, 5);
      expect(syncCalls, 0);
    });

    test('re-enqueues updated schedule when foreground changes interval after first read', () async {
      final updatedSchedule = BackupScheduleState(
        schedule: BackupSchedule.weekly,
        lastConfirmedAt: DateTime.utc(2026, 11, 24, 10),
        nextDueAt: DateTime.utc(2026, 12, 1, 10),
      );
      var readCalls = 0;
      final syncedSchedules = <BackupScheduleState>[];

      await reconcileBackupWorkerSuccessor(
        readScheduleState: () async {
          readCalls++;
          if (readCalls == 1) return Right(persistedSchedule);
          return Right(updatedSchedule);
        },
        syncSchedule: (schedule, _) async {
          syncedSchedules.add(schedule);
        },
        cancelSchedule: () async {},
        now: () => DateTime.utc(2026, 11, 24, 10, 1),
        retryDelay: Duration.zero,
      );

      expect(readCalls, 3);
      expect(syncedSchedules, [persistedSchedule, updatedSchedule]);
    });

    test('P12-15: 4 failed reads before pause still reconcile concurrent interval change after enqueue', () async {
      final updatedSchedule = BackupScheduleState(
        schedule: BackupSchedule.daily,
        lastConfirmedAt: DateTime.utc(2026, 11, 24, 10),
        nextDueAt: DateTime.utc(2026, 11, 25, 10),
      );
      final monthlySchedule = BackupScheduleState(
        schedule: BackupSchedule.monthly,
        lastConfirmedAt: DateTime.utc(2026, 11, 24, 10),
        nextDueAt: DateTime.utc(2026, 12, 24, 10),
      );
      var currentPersisted = monthlySchedule;
      var readCalls = 0;
      final syncedSchedules = <BackupScheduleState>[];

      await reconcileBackupWorkerSuccessor(
        readScheduleState: () async {
          readCalls++;
          if (readCalls <= 4) {
            return const Left(AppFailure(AppErrorCode.database));
          }
          return Right(currentPersisted);
        },
        onPauseAfterFinalRead: () async {
          currentPersisted = updatedSchedule;
        },
        syncSchedule: (schedule, _) async {
          syncedSchedules.add(schedule);
        },
        cancelSchedule: () async {},
        now: () => DateTime.utc(2026, 11, 24, 10, 1),
        retryDelay: Duration.zero,
      );

      expect(readCalls, 7);
      expect(syncedSchedules, [monthlySchedule, updatedSchedule]);
    });

    test('P12-15: throws recoverable error if schedule keeps changing across all five rounds', () async {
      final schedules = List.generate(
        6,
        (i) => BackupScheduleState(
          schedule: i.isEven ? BackupSchedule.daily : BackupSchedule.weekly,
          lastConfirmedAt: DateTime.utc(2026, 11, 24, 10),
          nextDueAt: DateTime.utc(2026, 11, 25 + i, 10),
        ),
      );
      var currentIndex = 0;
      final syncedSchedules = <BackupScheduleState>[];

      await expectLater(
        reconcileBackupWorkerSuccessor(
          readScheduleState: () async => Right(schedules[currentIndex]),
          syncSchedule: (schedule, _) async {
            syncedSchedules.add(schedule);
            if (currentIndex < schedules.length - 1) {
              currentIndex++;
            }
          },
          cancelSchedule: () async {},
          now: () => DateTime.utc(2026, 11, 24, 10, 1),
          retryDelay: Duration.zero,
        ),
        throwsStateError,
      );

      expect(syncedSchedules, schedules.sublist(0, 5));
    });

    test('P12-15: succeeds on fifth round when schedule stabilizes on final persisted target', () async {
      final schedules = List.generate(
        5,
        (i) => BackupScheduleState(
          schedule: i.isEven ? BackupSchedule.daily : BackupSchedule.weekly,
          lastConfirmedAt: DateTime.utc(2026, 11, 24, 10),
          nextDueAt: DateTime.utc(2026, 11, 25 + i, 10),
        ),
      );
      var currentIndex = 0;
      final syncedSchedules = <BackupScheduleState>[];

      await reconcileBackupWorkerSuccessor(
        readScheduleState: () async => Right(schedules[currentIndex]),
        syncSchedule: (schedule, _) async {
          syncedSchedules.add(schedule);
          if (currentIndex < schedules.length - 1) {
            currentIndex++;
          }
        },
        cancelSchedule: () async {},
        now: () => DateTime.utc(2026, 11, 24, 10, 1),
        retryDelay: Duration.zero,
      );

      expect(syncedSchedules, schedules);
      expect(syncedSchedules.last, schedules.last);
    });
  });
}
