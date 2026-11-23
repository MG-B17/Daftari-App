import 'dart:async';

/// Serializes session invalidation (sign-out) against the final SQLite commit
/// phase of cloud backup acknowledgment.
///
/// - If session invalidation begins before the backup transaction enters its
///   final commit phase, [isInvalidating] is immediately `true` so the
///   pre-commit guard aborts and rolls back SQLite before committing.
/// - If the backup transaction has already passed its final pre-commit guard
///   and entered SQLite `COMMIT`, [runSessionInvalidation] waits for that
///   authorized commit to complete before clearing the auth session.
class SessionCommitGate {
  Completer<void>? _activeCommit;
  int _pendingInvalidations = 0;

  bool get isInvalidating => _pendingInvalidations > 0;

  /// Enters the final SQLite `COMMIT` critical section.
  ///
  /// Must be called synchronously immediately after the pre-commit authority
  /// guard succeeds and paired with [endCommit] in a `finally` block.
  void beginCommit() {
    assert(_activeCommit == null, 'Nested backup commits are not supported');
    _activeCommit = Completer<void>();
  }

  /// Exits the final SQLite `COMMIT` critical section, releasing any waiting
  /// session invalidations.
  void endCommit() {
    final active = _activeCommit;
    _activeCommit = null;
    if (active != null && !active.isCompleted) {
      active.complete();
    }
  }

  /// Runs [invalidate] strictly ordered with any in-flight backup commit.
  Future<void> runSessionInvalidation(
    Future<void> Function() invalidate,
  ) async {
    _pendingInvalidations++;
    try {
      while (_activeCommit != null) {
        await _activeCommit!.future;
      }
      await invalidate();
    } finally {
      _pendingInvalidations--;
    }
  }
}
