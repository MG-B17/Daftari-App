import 'package:daftariapp/features/backup/domain/entities/backup_eligibility.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_schedule.dart';
import 'package:daftariapp/features/backup/domain/policies/backup_cutoff_policy.dart';
import 'package:daftariapp/features/backup/domain/policies/backup_eligibility_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 24, 10);

  final dueSchedule = BackupScheduleState(
    schedule: BackupSchedule.daily,
    lastConfirmedAt: DateTime.utc(2026, 11, 23, 10),
    nextDueAt: now,
  );

  const eligibleContext = BackupEligibilityContext(
    authenticatedUserId: 'user-a',
    isEmailVerified: true,
    linkedOwnerUserId: 'user-a',
    deviceId: 'device-1',
    isActiveDevice: true,
    pendingChangesCount: 2,
    hasConnectivity: true,
  );

  group('BackupEligibilityPolicy', () {
    test('allows both manual and scheduled triggers when all rules pass', () {
      expect(
        BackupEligibilityPolicy.evaluate(
          trigger: BackupTrigger.manual,
          context: eligibleContext,
          scheduleState: const BackupScheduleState.initial(),
          now: now,
        ),
        const BackupEligibilityDecision.eligible(),
      );
      expect(
        BackupEligibilityPolicy.canBackUpNow(
          context: eligibleContext,
          scheduleState: const BackupScheduleState.initial(),
          now: now,
        ),
        isTrue,
      );
      expect(
        BackupEligibilityPolicy.evaluate(
          trigger: BackupTrigger.scheduled,
          context: eligibleContext,
          scheduleState: dueSchedule,
          now: now,
        ),
        const BackupEligibilityDecision.eligible(),
      );
    });

    test('enforces schedule presence and due time for scheduled runs only', () {
      expect(
        BackupEligibilityPolicy.evaluate(
          trigger: BackupTrigger.scheduled,
          context: eligibleContext,
          scheduleState: const BackupScheduleState.initial(),
          now: now,
        ),
        const BackupEligibilityDecision.ineligible(
          BackupIneligibilityReason.noScheduleConfigured,
        ),
      );

      final notDueYet = BackupScheduleState(
        schedule: BackupSchedule.daily,
        lastConfirmedAt: DateTime.utc(2026, 11, 24, 9),
        nextDueAt: DateTime.utc(2026, 11, 25, 9),
      );
      expect(
        BackupEligibilityPolicy.evaluate(
          trigger: BackupTrigger.scheduled,
          context: eligibleContext,
          scheduleState: notDueYet,
          now: now,
        ),
        const BackupEligibilityDecision.ineligible(
          BackupIneligibilityReason.notDueYet,
        ),
      );
      expect(
        BackupEligibilityPolicy.canBackUpNow(
          context: eligibleContext,
          scheduleState: notDueYet,
          now: now,
        ),
        isTrue,
      );
    });

    test(
      'applies identical core eligibility gates to manual and scheduled',
      () {
        final cases =
            <(String, BackupEligibilityContext, BackupIneligibilityReason)>[
              (
                'already running',
                eligibleContext.copyWith(isBackupRunning: true),
                BackupIneligibilityReason.alreadyRunning,
              ),
              (
                'signed out',
                const BackupEligibilityContext(
                  authenticatedUserId: null,
                  isEmailVerified: true,
                  linkedOwnerUserId: 'user-a',
                  deviceId: 'device-1',
                  isActiveDevice: true,
                  pendingChangesCount: 2,
                  hasConnectivity: true,
                ),
                BackupIneligibilityReason.signedOut,
              ),
              (
                'unverified email',
                const BackupEligibilityContext(
                  authenticatedUserId: 'user-a',
                  isEmailVerified: false,
                  linkedOwnerUserId: 'user-a',
                  deviceId: 'device-1',
                  isActiveDevice: true,
                  pendingChangesCount: 2,
                  hasConnectivity: true,
                ),
                BackupIneligibilityReason.emailNotVerified,
              ),
              (
                'unlinked ledger',
                const BackupEligibilityContext(
                  authenticatedUserId: 'user-a',
                  isEmailVerified: true,
                  linkedOwnerUserId: null,
                  deviceId: 'device-1',
                  isActiveDevice: true,
                  pendingChangesCount: 2,
                  hasConnectivity: true,
                ),
                BackupIneligibilityReason.ledgerUnlinked,
              ),
              (
                'account mismatch',
                const BackupEligibilityContext(
                  authenticatedUserId: 'user-b',
                  isEmailVerified: true,
                  linkedOwnerUserId: 'user-a',
                  deviceId: 'device-1',
                  isActiveDevice: true,
                  pendingChangesCount: 2,
                  hasConnectivity: true,
                ),
                BackupIneligibilityReason.accountMismatch,
              ),
              (
                'inactive device',
                const BackupEligibilityContext(
                  authenticatedUserId: 'user-a',
                  isEmailVerified: true,
                  linkedOwnerUserId: 'user-a',
                  deviceId: 'device-1',
                  isActiveDevice: false,
                  pendingChangesCount: 2,
                  hasConnectivity: true,
                ),
                BackupIneligibilityReason.inactiveDevice,
              ),
              (
                'missing device id',
                const BackupEligibilityContext(
                  authenticatedUserId: 'user-a',
                  isEmailVerified: true,
                  linkedOwnerUserId: 'user-a',
                  deviceId: '   ',
                  isActiveDevice: true,
                  pendingChangesCount: 2,
                  hasConnectivity: true,
                ),
                BackupIneligibilityReason.inactiveDevice,
              ),
              (
                'no pending changes',
                const BackupEligibilityContext(
                  authenticatedUserId: 'user-a',
                  isEmailVerified: true,
                  linkedOwnerUserId: 'user-a',
                  deviceId: 'device-1',
                  isActiveDevice: true,
                  pendingChangesCount: 0,
                  hasConnectivity: true,
                ),
                BackupIneligibilityReason.noPendingChanges,
              ),
              (
                'offline',
                const BackupEligibilityContext(
                  authenticatedUserId: 'user-a',
                  isEmailVerified: true,
                  linkedOwnerUserId: 'user-a',
                  deviceId: 'device-1',
                  isActiveDevice: true,
                  pendingChangesCount: 2,
                  hasConnectivity: false,
                ),
                BackupIneligibilityReason.offline,
              ),
            ];

        for (final (label, context, expectedReason) in cases) {
          for (final trigger in BackupTrigger.values) {
            expect(
              BackupEligibilityPolicy.evaluate(
                trigger: trigger,
                context: context,
                scheduleState: dueSchedule,
                now: now,
              ),
              BackupEligibilityDecision.ineligible(expectedReason),
              reason: '$label for ${trigger.name}',
            );
          }
        }
      },
    );
  });

  group('BackupCutoffPolicy', () {
    test('detects pending revisions and rejects invalid revision numbers', () {
      expect(
        BackupCutoffPolicy.isRecordPending(
          localRevision: 1,
          acknowledgedRevision: 0,
        ),
        isTrue,
      );
      expect(
        BackupCutoffPolicy.isRecordPending(
          localRevision: 1,
          acknowledgedRevision: 1,
        ),
        isFalse,
      );
      expect(
        BackupCutoffPolicy.isRecordPending(
          localRevision: 2,
          acknowledgedRevision: 1,
        ),
        isTrue,
      );

      expect(
        () => BackupCutoffPolicy.isRecordPending(
          localRevision: 0,
          acknowledgedRevision: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => BackupCutoffPolicy.isRecordPending(
          localRevision: 1,
          acknowledgedRevision: -1,
        ),
        throwsArgumentError,
      );
    });

    test('acknowledges captured revision without hiding newer local edits', () {
      // Unedited during upload: fully acknowledged
      expect(
        BackupCutoffPolicy.resolveAcknowledgedRevision(
          localRevision: 1,
          currentAcknowledgedRevision: 0,
          capturedRevision: 1,
        ),
        1,
      );
      expect(
        BackupCutoffPolicy.hasPendingChangesAfterAck(
          localRevision: 1,
          currentAcknowledgedRevision: 0,
          capturedRevision: 1,
        ),
        isFalse,
      );

      // Edited during upload (1 -> 2): rev 1 acknowledged, rev 2 stays pending
      expect(
        BackupCutoffPolicy.resolveAcknowledgedRevision(
          localRevision: 2,
          currentAcknowledgedRevision: 0,
          capturedRevision: 1,
        ),
        1,
      );
      expect(
        BackupCutoffPolicy.hasPendingChangesAfterAck(
          localRevision: 2,
          currentAcknowledgedRevision: 0,
          capturedRevision: 1,
        ),
        isTrue,
      );

      // Next run confirms rev 2: no longer pending
      expect(
        BackupCutoffPolicy.hasPendingChangesAfterAck(
          localRevision: 2,
          currentAcknowledgedRevision: 1,
          capturedRevision: 2,
        ),
        isFalse,
      );

      // Stale or repeated acknowledgment never moves backwards
      expect(
        BackupCutoffPolicy.resolveAcknowledgedRevision(
          localRevision: 3,
          currentAcknowledgedRevision: 2,
          capturedRevision: 1,
        ),
        2,
      );
      expect(
        () => BackupCutoffPolicy.resolveAcknowledgedRevision(
          localRevision: 1,
          currentAcknowledgedRevision: 0,
          capturedRevision: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => BackupCutoffPolicy.resolveAcknowledgedRevision(
          localRevision: 1,
          currentAcknowledgedRevision: 0,
          capturedRevision: 0,
        ),
        throwsArgumentError,
      );
    });

    test(
      'blocks acknowledgment after sign-out, account change or device loss',
      () {
        expect(
          BackupCutoffPolicy.acknowledgmentBlockReason(
            batchOwnerUserId: 'user-a',
            batchDeviceId: 'device-1',
            currentContext: eligibleContext,
          ),
          isNull,
        );
        expect(
          BackupCutoffPolicy.acknowledgmentBlockReason(
            batchOwnerUserId: 'user-a',
            batchDeviceId: 'device-1',
            currentContext: const BackupEligibilityContext(
              authenticatedUserId: null,
              isEmailVerified: true,
              linkedOwnerUserId: 'user-a',
              deviceId: 'device-1',
              isActiveDevice: true,
              pendingChangesCount: 1,
              hasConnectivity: true,
            ),
          ),
          BackupIneligibilityReason.signedOut,
        );
        expect(
          BackupCutoffPolicy.acknowledgmentBlockReason(
            batchOwnerUserId: 'user-a',
            batchDeviceId: 'device-1',
            currentContext: const BackupEligibilityContext(
              authenticatedUserId: 'user-b',
              isEmailVerified: true,
              linkedOwnerUserId: 'user-a',
              deviceId: 'device-1',
              isActiveDevice: true,
              pendingChangesCount: 1,
              hasConnectivity: true,
            ),
          ),
          BackupIneligibilityReason.accountMismatch,
        );
        expect(
          BackupCutoffPolicy.acknowledgmentBlockReason(
            batchOwnerUserId: 'user-a',
            batchDeviceId: 'device-1',
            currentContext: const BackupEligibilityContext(
              authenticatedUserId: 'user-a',
              isEmailVerified: true,
              linkedOwnerUserId: 'user-a',
              deviceId: 'device-2',
              isActiveDevice: true,
              pendingChangesCount: 1,
              hasConnectivity: true,
            ),
          ),
          BackupIneligibilityReason.inactiveDevice,
        );
      },
    );
  });
}
