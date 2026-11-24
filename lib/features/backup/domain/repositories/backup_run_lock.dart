/// Single-flight execution lock coordinating manual and scheduled backup runs
/// within a process and across Android process boundaries.
abstract interface class BackupRunLock {
  bool get isLocked;

  /// Acquires exclusive execution rights or returns `null` if a backup run is
  /// already active.
  Future<BackupRunLease?> tryAcquire();
}

abstract interface class BackupRunLease {
  Future<void> release();
}
