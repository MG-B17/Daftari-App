import '../entities/backup_eligibility.dart';
import '../entities/backup_schedule.dart';
import 'backup_schedule_policy.dart';

/// Shared eligibility rules enforced by both manual and scheduled entry points.
abstract final class BackupEligibilityPolicy {
  static BackupEligibilityDecision evaluate({
    required BackupTrigger trigger,
    required BackupEligibilityContext context,
    required BackupScheduleState scheduleState,
    required DateTime now,
  }) {
    if (context.isBackupRunning) {
      return const BackupEligibilityDecision.ineligible(
        BackupIneligibilityReason.alreadyRunning,
      );
    }

    if (trigger == BackupTrigger.scheduled) {
      if (!scheduleState.hasSchedule) {
        return const BackupEligibilityDecision.ineligible(
          BackupIneligibilityReason.noScheduleConfigured,
        );
      }
      if (!BackupSchedulePolicy.isDue(scheduleState, now)) {
        return const BackupEligibilityDecision.ineligible(
          BackupIneligibilityReason.notDueYet,
        );
      }
    }

    if (!context.hasAuthenticatedUser) {
      return const BackupEligibilityDecision.ineligible(
        BackupIneligibilityReason.signedOut,
      );
    }
    if (!context.isEmailVerified) {
      return const BackupEligibilityDecision.ineligible(
        BackupIneligibilityReason.emailNotVerified,
      );
    }
    if (!context.hasLinkedOwner) {
      return const BackupEligibilityDecision.ineligible(
        BackupIneligibilityReason.ledgerUnlinked,
      );
    }
    if (!context.isMatchingLinkedAccount) {
      return const BackupEligibilityDecision.ineligible(
        BackupIneligibilityReason.accountMismatch,
      );
    }
    if (!context.hasDeviceId || !context.isActiveDevice) {
      return const BackupEligibilityDecision.ineligible(
        BackupIneligibilityReason.inactiveDevice,
      );
    }
    if (!context.hasPendingChanges) {
      return const BackupEligibilityDecision.ineligible(
        BackupIneligibilityReason.noPendingChanges,
      );
    }
    if (!context.hasConnectivity) {
      return const BackupEligibilityDecision.ineligible(
        BackupIneligibilityReason.offline,
      );
    }

    return const BackupEligibilityDecision.eligible();
  }

  static bool canBackUpNow({
    required BackupEligibilityContext context,
    required BackupScheduleState scheduleState,
    required DateTime now,
  }) => evaluate(
    trigger: BackupTrigger.manual,
    context: context,
    scheduleState: scheduleState,
    now: now,
  ).isEligible;
}
