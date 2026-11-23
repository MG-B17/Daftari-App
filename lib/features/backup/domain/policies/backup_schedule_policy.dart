import '../entities/backup_schedule.dart';

/// Pure scheduling rules using explicit UTC timestamps.
abstract final class BackupSchedulePolicy {
  /// Computes the next due instant after [anchor] for [schedule]:
  /// - Daily: +1 day
  /// - Weekly: +7 days
  /// - Monthly: corresponding day next month, clamped to the target month end.
  static DateTime nextDueAfter(DateTime anchor, BackupSchedule schedule) {
    final utc = anchor.toUtc();
    return switch (schedule) {
      BackupSchedule.daily => utc.add(const Duration(days: 1)),
      BackupSchedule.weekly => utc.add(const Duration(days: 7)),
      BackupSchedule.monthly => _addOneCalendarMonth(utc),
    };
  }

  /// Due is inclusive of the exact [BackupScheduleState.nextDueAt] boundary.
  static bool isDue(BackupScheduleState state, DateTime now) {
    final nextDue = state.nextDueAt;
    if (nextDue == null) return false;
    return !now.toUtc().isBefore(nextDue);
  }

  static bool isOverdue(BackupScheduleState state, DateTime now) {
    final nextDue = state.nextDueAt;
    if (nextDue == null) return false;
    return now.toUtc().isAfter(nextDue);
  }

  static Duration? timeUntilNextDue(BackupScheduleState state, DateTime now) {
    final nextDue = state.nextDueAt;
    if (nextDue == null) return null;
    final remaining = nextDue.difference(now.toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Selects the first schedule or replaces the active schedule with one new
  /// active schedule while preserving [BackupScheduleState.lastConfirmedAt].
  static BackupScheduleState selectSchedule(
    BackupScheduleState current,
    BackupSchedule schedule, {
    required DateTime now,
    required bool hasPendingChanges,
  }) {
    if (current.schedule == schedule) return current;

    final nowUtc = now.toUtc();
    final lastConfirmed = current.lastConfirmedAt;
    if (lastConfirmed == null) {
      return BackupScheduleState(
        schedule: schedule,
        nextDueAt: nextDueAfter(nowUtc, schedule),
      );
    }

    final candidate = nextDueAfter(lastConfirmed, schedule);
    final nextDue = !hasPendingChanges && !candidate.isAfter(nowUtc)
        ? nextDueAfter(nowUtc, schedule)
        : candidate;
    return BackupScheduleState(
      schedule: schedule,
      lastConfirmedAt: lastConfirmed,
      nextDueAt: nextDue,
    );
  }

  /// Records a server-confirmed manual or scheduled backup, updating the
  /// confirmed timestamp and restarting any active schedule interval.
  static BackupScheduleState recordConfirmation(
    BackupScheduleState current, {
    required DateTime confirmedAt,
  }) {
    final confirmedUtc = confirmedAt.toUtc();
    final schedule = current.schedule;
    if (schedule == null) {
      return BackupScheduleState(lastConfirmedAt: confirmedUtc);
    }
    return BackupScheduleState(
      schedule: schedule,
      lastConfirmedAt: confirmedUtc,
      nextDueAt: nextDueAfter(confirmedUtc, schedule),
    );
  }

  /// Advances an overdue or due schedule when the ledger has zero pending
  /// changes so an unchanged overdue ledger cannot cause a retry loop.
  /// Preserves [BackupScheduleState.lastConfirmedAt].
  static BackupScheduleState recordSkippedNoChanges(
    BackupScheduleState current, {
    required DateTime now,
  }) {
    final schedule = current.schedule;
    if (schedule == null || !isDue(current, now)) return current;
    return BackupScheduleState(
      schedule: schedule,
      lastConfirmedAt: current.lastConfirmedAt,
      nextDueAt: nextDueAfter(now.toUtc(), schedule),
    );
  }

  /// Failed, offline, or otherwise blocked runs preserve both the last
  /// confirmed timestamp and any overdue due date so eligible retries happen.
  static BackupScheduleState recordFailure(BackupScheduleState current) =>
      current;

  static DateTime _addOneCalendarMonth(DateTime utc) {
    final nextYear = utc.month == 12 ? utc.year + 1 : utc.year;
    final nextMonth = utc.month == 12 ? 1 : utc.month + 1;
    final lastDayOfNextMonth = DateTime.utc(nextYear, nextMonth + 1, 0).day;
    final clampedDay = utc.day > lastDayOfNextMonth
        ? lastDayOfNextMonth
        : utc.day;
    return DateTime.utc(
      nextYear,
      nextMonth,
      clampedDay,
      utc.hour,
      utc.minute,
      utc.second,
      utc.millisecond,
      utc.microsecond,
    );
  }
}
