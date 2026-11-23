import 'package:daftariapp/features/backup/domain/entities/backup_schedule.dart';
import 'package:daftariapp/features/backup/domain/policies/backup_schedule_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupScheduleState invariants', () {
    test('initial state has no active schedule or confirmed time', () {
      const state = BackupScheduleState.initial();
      expect(state.schedule, isNull);
      expect(state.lastConfirmedAt, isNull);
      expect(state.nextDueAt, isNull);
      expect(state.hasSchedule, isFalse);
      expect(state.hasConfirmedBackup, isFalse);
    });

    test(
      'normalizes timestamps to UTC and enforces schedule/nextDue pairing',
      () {
        final localConfirmed = DateTime(2026, 11, 20, 14, 30);
        final localDue = DateTime(2026, 11, 21, 14, 30);
        final state = BackupScheduleState(
          schedule: BackupSchedule.daily,
          lastConfirmedAt: localConfirmed,
          nextDueAt: localDue,
        );
        expect(state.lastConfirmedAt!.isUtc, isTrue);
        expect(state.nextDueAt!.isUtc, isTrue);
        expect(
          state,
          BackupScheduleState(
            schedule: BackupSchedule.daily,
            lastConfirmedAt: localConfirmed.toUtc(),
            nextDueAt: localDue.toUtc(),
          ),
        );

        expect(
          () => BackupScheduleState(schedule: BackupSchedule.daily),
          throwsFormatException,
        );
        expect(
          () => BackupScheduleState(nextDueAt: DateTime.utc(2026, 11, 21)),
          throwsFormatException,
        );
      },
    );
  });

  group('Interval boundaries', () {
    test('daily adds exactly 1 day across month, leap and year boundaries', () {
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2026, 1, 31, 23, 59, 59, 999),
          BackupSchedule.daily,
        ),
        DateTime.utc(2026, 2, 1, 23, 59, 59, 999),
      );
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2028, 2, 28, 10, 15),
          BackupSchedule.daily,
        ),
        DateTime.utc(2028, 2, 29, 10, 15),
      );
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2026, 12, 31, 12),
          BackupSchedule.daily,
        ),
        DateTime.utc(2027, 1, 1, 12),
      );
    });

    test('weekly adds exactly 7 days across month and year boundaries', () {
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2026, 11, 25, 9, 30),
          BackupSchedule.weekly,
        ),
        DateTime.utc(2026, 12, 2, 9, 30),
      );
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2026, 12, 28, 8),
          BackupSchedule.weekly,
        ),
        DateTime.utc(2027, 1, 4, 8),
      );
    });

    test('monthly uses corresponding date next month clamped to month end', () {
      // Non-leap February (28 days)
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2026, 1, 31, 10, 30, 45, 123, 456),
          BackupSchedule.monthly,
        ),
        DateTime.utc(2026, 2, 28, 10, 30, 45, 123, 456),
      );
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2026, 1, 29, 10),
          BackupSchedule.monthly,
        ),
        DateTime.utc(2026, 2, 28, 10),
      );
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2026, 1, 28, 10),
          BackupSchedule.monthly,
        ),
        DateTime.utc(2026, 2, 28, 10),
      );

      // Leap February (29 days)
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2028, 1, 31, 10, 30),
          BackupSchedule.monthly,
        ),
        DateTime.utc(2028, 2, 29, 10, 30),
      );
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2028, 1, 30, 10, 30),
          BackupSchedule.monthly,
        ),
        DateTime.utc(2028, 2, 29, 10, 30),
      );

      // Century non-leap (2100) and 400-year leap (2000)
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2100, 1, 31, 12),
          BackupSchedule.monthly,
        ),
        DateTime.utc(2100, 2, 28, 12),
      );
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2000, 1, 31, 12),
          BackupSchedule.monthly,
        ),
        DateTime.utc(2000, 2, 29, 12),
      );

      // 31-day -> 30-day months
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2026, 3, 31, 23, 59, 59),
          BackupSchedule.monthly,
        ),
        DateTime.utc(2026, 4, 30, 23, 59, 59),
      );
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2026, 5, 31, 8),
          BackupSchedule.monthly,
        ),
        DateTime.utc(2026, 6, 30, 8),
      );

      // Year rollover and short -> long month
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2026, 12, 31, 14),
          BackupSchedule.monthly,
        ),
        DateTime.utc(2027, 1, 31, 14),
      );
      expect(
        BackupSchedulePolicy.nextDueAfter(
          DateTime.utc(2026, 2, 28, 14),
          BackupSchedule.monthly,
        ),
        DateTime.utc(2026, 3, 28, 14),
      );
    });

    test(
      'due boundary is inclusive and overdue is strictly after nextDueAt',
      () {
        final due = DateTime.utc(2026, 11, 24, 10);
        final state = BackupScheduleState(
          schedule: BackupSchedule.daily,
          lastConfirmedAt: DateTime.utc(2026, 11, 23, 10),
          nextDueAt: due,
        );

        final before = due.subtract(const Duration(microseconds: 1));
        final after = due.add(const Duration(microseconds: 1));

        expect(BackupSchedulePolicy.isDue(state, before), isFalse);
        expect(BackupSchedulePolicy.isOverdue(state, before), isFalse);
        expect(
          BackupSchedulePolicy.timeUntilNextDue(state, before),
          const Duration(microseconds: 1),
        );

        expect(BackupSchedulePolicy.isDue(state, due), isTrue);
        expect(BackupSchedulePolicy.isOverdue(state, due), isFalse);
        expect(
          BackupSchedulePolicy.timeUntilNextDue(state, due),
          Duration.zero,
        );

        expect(BackupSchedulePolicy.isDue(state, after), isTrue);
        expect(BackupSchedulePolicy.isOverdue(state, after), isTrue);
        expect(
          BackupSchedulePolicy.timeUntilNextDue(state, after),
          Duration.zero,
        );
      },
    );

    test('no schedule is never due or overdue', () {
      final now = DateTime.utc(2026, 11, 23, 10);
      const initial = BackupScheduleState.initial();
      expect(BackupSchedulePolicy.isDue(initial, now), isFalse);
      expect(BackupSchedulePolicy.isOverdue(initial, now), isFalse);
      expect(BackupSchedulePolicy.timeUntilNextDue(initial, now), isNull);
    });
  });

  group('Schedule selection, replacement, confirmation and skip rules', () {
    final day1 = DateTime.utc(2026, 11, 1, 10);

    test('first selection without confirmed backup anchors on now', () {
      final selected = BackupSchedulePolicy.selectSchedule(
        const BackupScheduleState.initial(),
        BackupSchedule.daily,
        now: day1,
        hasPendingChanges: true,
      );
      expect(selected.schedule, BackupSchedule.daily);
      expect(selected.lastConfirmedAt, isNull);
      expect(selected.nextDueAt, DateTime.utc(2026, 11, 2, 10));
    });

    test('replacing schedule leaves one active schedule and preserves lastConfirmedAt', () {
      final daily = BackupScheduleState(
        schedule: BackupSchedule.daily,
        lastConfirmedAt: day1,
        nextDueAt: DateTime.utc(2026, 11, 2, 10),
      );
      final replaced = BackupSchedulePolicy.selectSchedule(
        daily,
        BackupSchedule.weekly,
        now: DateTime.utc(2026, 11, 1, 18),
        hasPendingChanges: true,
      );
      expect(replaced.schedule, BackupSchedule.weekly);
      expect(replaced.lastConfirmedAt, day1);
      expect(replaced.nextDueAt, DateTime.utc(2026, 11, 8, 10));
    });

    test('shortening schedule becomes immediately due when pending, but avoids retry loop when unchanged', () {
      final monthly = BackupScheduleState(
        schedule: BackupSchedule.monthly,
        lastConfirmedAt: day1,
        nextDueAt: DateTime.utc(2026, 12, 1, 10),
      );
      final day10 = DateTime.utc(2026, 11, 11, 10);

      final withPending = BackupSchedulePolicy.selectSchedule(
        monthly,
        BackupSchedule.weekly,
        now: day10,
        hasPendingChanges: true,
      );
      expect(withPending.nextDueAt, DateTime.utc(2026, 11, 8, 10));
      expect(BackupSchedulePolicy.isDue(withPending, day10), isTrue);

      final unchanged = BackupSchedulePolicy.selectSchedule(
        monthly,
        BackupSchedule.weekly,
        now: day10,
        hasPendingChanges: false,
      );
      expect(unchanged.lastConfirmedAt, day1);
      expect(unchanged.nextDueAt, DateTime.utc(2026, 11, 18, 10));
      expect(BackupSchedulePolicy.isDue(unchanged, day10), isFalse);
    });

    test('re-selecting the same active schedule is a no-op', () {
      final state = BackupScheduleState(
        schedule: BackupSchedule.weekly,
        lastConfirmedAt: day1,
        nextDueAt: DateTime.utc(2026, 11, 8, 10),
      );
      final unchanged = BackupSchedulePolicy.selectSchedule(
        state,
        BackupSchedule.weekly,
        now: DateTime.utc(2026, 11, 5, 10),
        hasPendingChanges: true,
      );
      expect(unchanged, same(state));
    });

    test(
      'confirmed backup restarts active schedule and preserves null schedule',
      () {
        final confirmedAt = DateTime.utc(2026, 11, 4, 15, 30);

        final withoutSchedule = BackupSchedulePolicy.recordConfirmation(
          const BackupScheduleState.initial(),
          confirmedAt: confirmedAt,
        );
        expect(withoutSchedule.schedule, isNull);
        expect(withoutSchedule.nextDueAt, isNull);
        expect(withoutSchedule.lastConfirmedAt, confirmedAt);

        final withWeekly = BackupSchedulePolicy.recordConfirmation(
          BackupScheduleState(
            schedule: BackupSchedule.weekly,
            lastConfirmedAt: day1,
            nextDueAt: DateTime.utc(2026, 11, 8, 10),
          ),
          confirmedAt: confirmedAt,
        );
        expect(withWeekly.schedule, BackupSchedule.weekly);
        expect(withWeekly.lastConfirmedAt, confirmedAt);
        expect(withWeekly.nextDueAt, DateTime.utc(2026, 11, 11, 15, 30));
      },
    );

    test('skipping unchanged overdue schedule advances nextDueAt past now without touching lastConfirmedAt', () {
      final state = BackupScheduleState(
        schedule: BackupSchedule.monthly,
        lastConfirmedAt: DateTime.utc(2026, 1, 31, 10),
        nextDueAt: DateTime.utc(2026, 2, 28, 10),
      );

      // Before due time -> unchanged
      final beforeDue = DateTime.utc(2026, 2, 20, 10);
      expect(
        BackupSchedulePolicy.recordSkippedNoChanges(state, now: beforeDue),
        same(state),
      );

      // Months overdue -> advances past now in one step
      final monthsLater = DateTime.utc(2026, 4, 15, 10);
      final advanced = BackupSchedulePolicy.recordSkippedNoChanges(
        state,
        now: monthsLater,
      );
      expect(advanced.lastConfirmedAt, DateTime.utc(2026, 1, 31, 10));
      expect(advanced.nextDueAt, DateTime.utc(2026, 5, 15, 10));
      expect(BackupSchedulePolicy.isDue(advanced, monthsLater), isFalse);
    });

    test('failed run preserves lastConfirmedAt and overdue nextDueAt', () {
      final overdue = BackupScheduleState(
        schedule: BackupSchedule.daily,
        lastConfirmedAt: day1,
        nextDueAt: DateTime.utc(2026, 11, 2, 10),
      );
      expect(BackupSchedulePolicy.recordFailure(overdue), same(overdue));
    });
  });
}
