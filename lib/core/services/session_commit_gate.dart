import 'dart:async';

/// Optional cross-isolate / cross-process coordinator backing
/// [SessionCommitGate] (e.g., native Android process-wide lock/condition
/// synchronizing foreground sign-out with a background WorkManager isolate's
/// SQLite `COMMIT`).
abstract interface class SessionCommitCoordinator {
  Future<int> readEpoch();

  /// Atomically verifies that no session invalidation is active and that the
  /// session epoch still equals [expectedEpoch], then enters the commit
  /// critical section. Returns `false` if invalidation started or completed.
  Future<bool> tryEnterCommit({required int expectedEpoch});

  /// Exits the commit critical section and wakes any waiting invalidations.
  Future<void> exitCommit();

  /// Marks session invalidation in progress and waits until any active
  /// authorized commit completes.
  Future<void> beginSessionInvalidation();

  /// Completes session invalidation and advances the session epoch so any
  /// stale transaction cannot commit afterward.
  Future<void> endSessionInvalidation();
}

/// Serializes session invalidation (sign-out) against the final SQLite commit
/// phase of cloud backup acknowledgment across both same-isolate and
/// cross-isolate (Android background worker) entry points.
///
/// - If session invalidation begins before the backup transaction enters its
///   final commit phase, [isInvalidating] is immediately `true` (and the epoch
///   advances on completion) so the pre-commit guard aborts and rolls back
///   SQLite before committing.
/// - If the backup transaction has already passed its final pre-commit guard
///   and entered SQLite `COMMIT`, [runSessionInvalidation] waits for that
///   authorized commit to complete before clearing the auth session.
class SessionCommitGate {
  SessionCommitGate({SessionCommitCoordinator? coordinator})
    : this._(coordinator);

  SessionCommitGate._(this._coordinator);

  final SessionCommitCoordinator? _coordinator;

  Completer<void>? _activeCommit;
  int _pendingInvalidations = 0;
  int _localEpoch = 0;

  bool get isInvalidating => _pendingInvalidations > 0;

  int get localEpoch => _localEpoch;

  /// Reads the current session invalidation epoch (from the cross-isolate
  /// coordinator when configured, otherwise the local isolate epoch).
  Future<int> readEpoch() async {
    final coordinator = _coordinator;
    if (coordinator != null) {
      return coordinator.readEpoch();
    }
    return _localEpoch;
  }

  /// Atomically checks that no invalidation started or completed since
  /// [expectedEpoch] and enters the final SQLite `COMMIT` critical section.
  ///
  /// Returns `false` without entering commit when invalidation won the race.
  Future<bool> tryEnterCommit({required int expectedEpoch}) async {
    if (_pendingInvalidations > 0) return false;
    final coordinator = _coordinator;
    if (coordinator != null) {
      final entered = await coordinator.tryEnterCommit(
        expectedEpoch: expectedEpoch,
      );
      if (!entered) return false;
      if (_pendingInvalidations > 0) {
        await coordinator.exitCommit();
        return false;
      }
      beginCommit();
      return true;
    }
    if (_localEpoch != expectedEpoch) return false;
    beginCommit();
    return true;
  }

  /// Exits both local and cross-isolate commit critical sections.
  Future<void> exitCommit() async {
    endCommit();
    final coordinator = _coordinator;
    if (coordinator != null) {
      await coordinator.exitCommit();
    }
  }

  /// Enters the local final SQLite `COMMIT` critical section synchronously.
  ///
  /// Must be called synchronously immediately after the pre-commit authority
  /// guard succeeds and paired with [endCommit] in a `finally` block.
  void beginCommit() {
    assert(_activeCommit == null, 'Nested backup commits are not supported');
    _activeCommit = Completer<void>();
  }

  /// Exits the local final SQLite `COMMIT` critical section, releasing any
  /// waiting in-isolate session invalidations.
  void endCommit() {
    final active = _activeCommit;
    _activeCommit = null;
    if (active != null && !active.isCompleted) {
      active.complete();
    }
  }

  /// Runs [invalidate] strictly ordered with any in-flight backup commit
  /// (within this isolate and across Android background worker isolates).
  Future<void> runSessionInvalidation(
    Future<void> Function() invalidate,
  ) async {
    _pendingInvalidations++;
    var coordinatorEntered = false;
    final coordinator = _coordinator;
    try {
      while (_activeCommit != null) {
        await _activeCommit!.future;
      }
      if (coordinator != null) {
        await coordinator.beginSessionInvalidation();
        coordinatorEntered = true;
      }
      await invalidate();
    } finally {
      _localEpoch++;
      _pendingInvalidations--;
      if (coordinator != null && coordinatorEntered) {
        await coordinator.endSessionInvalidation();
      }
    }
  }
}
