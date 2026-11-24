import '../entities/backup_eligibility.dart';

/// Pure batch-cutoff and revision-checked acknowledgment rules.
abstract final class BackupCutoffPolicy {
  /// Returns `true` when local mutations exist beyond [acknowledgedRevision].
  static bool isRecordPending({
    required int localRevision,
    required int acknowledgedRevision,
  }) {
    _validateRevisions(
      localRevision: localRevision,
      acknowledgedRevision: acknowledgedRevision,
    );
    return localRevision > acknowledgedRevision;
  }

  /// Computes the monotonic acknowledged revision after a confirmed batch that
  /// captured [capturedRevision].
  ///
  /// If the record was edited or soft-deleted locally while the batch was in
  /// flight (`localRevision > capturedRevision`), the returned revision stays
  /// strictly below [localRevision] so the newer mutation remains pending.
  static int resolveAcknowledgedRevision({
    required int localRevision,
    required int currentAcknowledgedRevision,
    required int capturedRevision,
  }) {
    _validateRevisions(
      localRevision: localRevision,
      acknowledgedRevision: currentAcknowledgedRevision,
    );
    if (capturedRevision < 1) {
      throw ArgumentError.value(
        capturedRevision,
        'capturedRevision',
        'Must be at least 1',
      );
    }
    if (capturedRevision > localRevision) {
      throw ArgumentError.value(
        capturedRevision,
        'capturedRevision',
        'Cannot exceed localRevision ($localRevision)',
      );
    }
    return capturedRevision > currentAcknowledgedRevision
        ? capturedRevision
        : currentAcknowledgedRevision;
  }

  /// Returns `true` when the record still has unacknowledged local changes
  /// after applying [capturedRevision].
  static bool hasPendingChangesAfterAck({
    required int localRevision,
    required int currentAcknowledgedRevision,
    required int capturedRevision,
  }) {
    final nextAck = resolveAcknowledgedRevision(
      localRevision: localRevision,
      currentAcknowledgedRevision: currentAcknowledgedRevision,
      capturedRevision: capturedRevision,
    );
    return isRecordPending(
      localRevision: localRevision,
      acknowledgedRevision: nextAck,
    );
  }

  /// Re-checks session ownership and device authority before acknowledging a
  /// confirmed batch locally so sign-out or account switches during upload can
  /// never acknowledge another account's data.
  ///
  /// Returns `null` when acknowledgment is permitted, or the blocking
  /// [BackupIneligibilityReason] otherwise.
  static BackupIneligibilityReason? acknowledgmentBlockReason({
    required String batchOwnerUserId,
    required String batchDeviceId,
    required BackupEligibilityContext currentContext,
  }) {
    if (!currentContext.hasAuthenticatedUser) {
      return BackupIneligibilityReason.signedOut;
    }
    if (!currentContext.isEmailVerified) {
      return BackupIneligibilityReason.emailNotVerified;
    }
    if (!currentContext.hasLinkedOwner) {
      return BackupIneligibilityReason.ledgerUnlinked;
    }
    if (currentContext.authenticatedUserId != batchOwnerUserId ||
        currentContext.linkedOwnerUserId != batchOwnerUserId) {
      return BackupIneligibilityReason.accountMismatch;
    }
    if (!currentContext.hasDeviceId ||
        currentContext.deviceId != batchDeviceId ||
        !currentContext.isActiveDevice) {
      return BackupIneligibilityReason.inactiveDevice;
    }
    return null;
  }

  static void _validateRevisions({
    required int localRevision,
    required int acknowledgedRevision,
  }) {
    if (localRevision < 1) {
      throw ArgumentError.value(
        localRevision,
        'localRevision',
        'Must be at least 1',
      );
    }
    if (acknowledgedRevision < 0) {
      throw ArgumentError.value(
        acknowledgedRevision,
        'acknowledgedRevision',
        'Must be non-negative',
      );
    }
  }
}
