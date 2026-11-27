import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/session_commit_gate/session_commit_gate.dart';
import '../../domain/entities/backup_schedule.dart';
import '../../domain/policies/backup_schedule_policy.dart';
import '../../domain/repositories/backup_run_lock.dart';
import '../../domain/repositories/backup_scheduler.dart';

/// Flutter MethodChannel bridge to the Android [BackupCoordinator] and
/// WorkManager scheduler.
///
/// Provides one unified implementation for:
/// - [BackupScheduler] (replacing/canceling the single unique WorkManager job)
/// - [BackupRunLock] (cross-isolate / cross-process single-flight execution)
/// - [SessionCommitCoordinator] (ordering foreground sign-out against worker
///   SQLite commits)
///
/// Falls back cleanly to local in-memory coordination when running outside
/// Android (e.g., unit/widget tests without a native platform handler).
class AndroidBackupPlatformBridge
    implements BackupScheduler, BackupRunLock, SessionCommitCoordinator {
  AndroidBackupPlatformBridge({
    MethodChannel? channel,
    String? databaseName,
    String? storageNamespace,
    String? uniqueWorkName,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _databaseName = _cleanOrNull(databaseName),
       _storageNamespace = _cleanOrNull(storageNamespace),
       _uniqueWorkName = _cleanOrNull(uniqueWorkName) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const channelName = 'com.mgb.daftari/backup';
  static const defaultUniqueWorkName = 'com.mgb.daftari.cloud_backup.scheduled';

  final MethodChannel _channel;
  final _externalChanges = StreamController<void>.broadcast();

  String? _databaseName;
  String? _storageNamespace;
  String? _uniqueWorkName;

  bool _localLocked = false;
  bool _remoteLocked = false;
  int _fallbackEpoch = 0;
  int _fallbackPendingInvalidations = 0;
  Completer<void>? _fallbackActiveCommit;

  static String? _cleanOrNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Map<String, Object?> _scopedArgs([Map<String, Object?>? extra]) => {
    if (kDebugMode && _uniqueWorkName != null)
      'uniqueWorkName': _uniqueWorkName,
    if (kDebugMode && _databaseName != null) 'databaseName': _databaseName,
    if (kDebugMode && _storageNamespace != null)
      'storageNamespace': _storageNamespace,
    ...?extra,
  };

  Map<String, Object?>? _optionalScopedArgs() {
    final args = _scopedArgs();
    return args.isEmpty ? null : args;
  }

  Stream<void> get onExternalBackupStateChanged => _externalChanges.stream;

  @override
  bool get isLocked => _localLocked || _remoteLocked;

  Future<bool> refreshRemoteRunLocked() async {
    try {
      final locked =
          await _channel.invokeMethod<bool>(
            'isRunLocked',
            _optionalScopedArgs(),
          ) ??
          false;
      _remoteLocked = locked;
      return isLocked;
    } on MissingPluginException {
      return _localLocked;
    }
  }

  @override
  Future<BackupRunLease?> tryAcquire() async {
    if (_localLocked) return null;
    try {
      final acquired =
          await _channel.invokeMethod<bool>(
            'tryAcquireRunLock',
            _optionalScopedArgs(),
          ) ??
          false;
      if (!acquired) {
        _remoteLocked = true;
        return null;
      }
      _localLocked = true;
      _remoteLocked = true;
      return _PlatformRunLease(_releaseNativeLease);
    } on MissingPluginException {
      if (_localLocked) return null;
      _localLocked = true;
      return _PlatformRunLease(() async {
        _localLocked = false;
      });
    }
  }

  Future<void> _releaseNativeLease() async {
    _localLocked = false;
    _remoteLocked = false;
    try {
      await _channel.invokeMethod<void>(
        'releaseRunLock',
        _optionalScopedArgs(),
      );
    } on MissingPluginException {
      // No native handler in test environment.
    }
  }

  @override
  Future<void> syncSchedule(
    BackupScheduleState scheduleState, {
    required DateTime now,
  }) async {
    if (!scheduleState.hasSchedule) {
      await cancelScheduledBackup();
      return;
    }
    final remaining =
        BackupSchedulePolicy.timeUntilNextDue(scheduleState, now) ??
        Duration.zero;
    try {
      await _channel.invokeMethod<void>(
        'syncSchedule',
        _scopedArgs({
          'delayMs': remaining.inMilliseconds,
          'schedule': scheduleState.schedule!.name,
          'nextDueAtEpochMs': scheduleState.nextDueAt!
              .toUtc()
              .millisecondsSinceEpoch,
        }),
      );
    } on MissingPluginException {
      // No native WorkManager in headless unit/widget tests.
    }
  }

  /// Enqueues the successor scheduled backup job from inside a finishing
  /// [BackupWorker] without cancelling the currently running worker request.
  Future<void> syncScheduleFromWorker(
    BackupScheduleState scheduleState, {
    required DateTime now,
    required String token,
  }) async {
    if (!scheduleState.hasSchedule) {
      await cancelScheduledBackupFromWorker(token: token);
      return;
    }
    final remaining =
        BackupSchedulePolicy.timeUntilNextDue(scheduleState, now) ??
        Duration.zero;
    try {
      await _channel.invokeMethod<void>(
        'syncScheduleFromWorker',
        _scopedArgs({
          'token': token,
          'delayMs': remaining.inMilliseconds,
          'schedule': scheduleState.schedule!.name,
          'nextDueAtEpochMs': scheduleState.nextDueAt!
              .toUtc()
              .millisecondsSinceEpoch,
        }),
      );
    } on MissingPluginException {
      // No native WorkManager in headless unit/widget tests.
    }
  }

  /// Cancels any other pending scheduled backup jobs from inside a finishing
  /// [BackupWorker] without cancelling the currently running worker request.
  Future<void> cancelScheduledBackupFromWorker({required String token}) async {
    try {
      await _channel.invokeMethod<void>(
        'cancelScheduleFromWorker',
        _scopedArgs({'token': token}),
      );
    } on MissingPluginException {
      // No native WorkManager in headless unit/widget tests.
    }
  }

  @override
  Future<void> cancelScheduledBackup() async {
    try {
      await _channel.invokeMethod<void>(
        'cancelSchedule',
        _optionalScopedArgs(),
      );
    } on MissingPluginException {
      // No native WorkManager in headless unit/widget tests.
    }
  }

  @override
  Future<int> readEpoch() async {
    try {
      return await _channel.invokeMethod<int>(
            'readSessionEpoch',
            _optionalScopedArgs(),
          ) ??
          0;
    } on MissingPluginException {
      return _fallbackEpoch;
    }
  }

  @override
  Future<bool> tryEnterCommit({required int expectedEpoch}) async {
    try {
      return await _channel.invokeMethod<bool>(
            'tryEnterCommit',
            _scopedArgs({'expectedEpoch': expectedEpoch}),
          ) ??
          false;
    } on MissingPluginException {
      if (_fallbackPendingInvalidations > 0 ||
          _fallbackEpoch != expectedEpoch) {
        return false;
      }
      _fallbackActiveCommit = Completer<void>();
      return true;
    }
  }

  @override
  Future<void> exitCommit() async {
    try {
      await _channel.invokeMethod<void>('exitCommit', _optionalScopedArgs());
    } on MissingPluginException {
      final active = _fallbackActiveCommit;
      _fallbackActiveCommit = null;
      if (active != null && !active.isCompleted) {
        active.complete();
      }
    }
  }

  @override
  Future<void> beginSessionInvalidation() async {
    try {
      await _channel.invokeMethod<void>(
        'beginSessionInvalidation',
        _optionalScopedArgs(),
      );
    } on MissingPluginException {
      _fallbackPendingInvalidations++;
      while (_fallbackActiveCommit != null) {
        await _fallbackActiveCommit!.future;
      }
    }
  }

  @override
  Future<void> endSessionInvalidation() async {
    try {
      await _channel.invokeMethod<void>(
        'endSessionInvalidation',
        _optionalScopedArgs(),
      );
    } on MissingPluginException {
      _fallbackEpoch++;
      if (_fallbackPendingInvalidations > 0) {
        _fallbackPendingInvalidations--;
      }
    }
  }

  Future<void> notifyBackupStateChanged() async {
    try {
      await _channel.invokeMethod<void>('notifyBackupStateChanged');
    } on MissingPluginException {
      // Ignore outside Android.
    }
  }

  Future<void> completeWorker({
    required String token,
    required BackupWorkerOutcome outcome,
  }) async {
    try {
      await _channel.invokeMethod<void>('completeWorker', {
        'token': token,
        'outcome': outcome.name,
      });
    } on MissingPluginException {
      // Ignore outside Android.
    }
  }

  Future<int> getScheduledWorkCount() async {
    try {
      return await _channel.invokeMethod<int>(
            'getScheduledWorkCount',
            _optionalScopedArgs(),
          ) ??
          0;
    } on MissingPluginException {
      return 0;
    }
  }

  // Debug-only Android integration test hooks (inert in release builds).

  Future<void> configureTestEnvironment({
    required String databaseName,
    required String storageNamespace,
    String? uniqueWorkName,
  }) async {
    if (!kDebugMode) return;
    _databaseName = _cleanOrNull(databaseName);
    _storageNamespace = _cleanOrNull(storageNamespace);
    _uniqueWorkName =
        _cleanOrNull(uniqueWorkName) ?? '$defaultUniqueWorkName.test';
    await _channel.invokeMethod<void>(
      'configureTestEnvironment',
      _scopedArgs(),
    );
  }

  Future<String?> enqueueImmediateWorkForTest({
    bool requireNetwork = false,
    String workerMode = 'production',
    String? schedule,
    int? nextDueAtEpochMs,
  }) async {
    if (!kDebugMode) return null;
    return _channel.invokeMethod<String>(
      'enqueueImmediateWorkForTest',
      _scopedArgs({
        'requireNetwork': requireNetwork,
        'workerMode': workerMode,
        'schedule': ?schedule,
        'nextDueAtEpochMs': ?nextDueAtEpochMs,
      }),
    );
  }

  Future<String?> getWorkStateForTest(String workId) async {
    if (!kDebugMode) return null;
    return _channel.invokeMethod<String>('getWorkStateForTest', {
      'workId': workId,
    });
  }

  Future<List<Map<String, Object?>>> getUniqueWorkInfosForTest() async {
    if (!kDebugMode) return const [];
    final raw = await _channel.invokeMethod<List<Object?>>(
      'getUniqueWorkInfosForTest',
      _optionalScopedArgs(),
    );
    return _decodeWorkInfos(raw);
  }

  Future<List<Map<String, Object?>>>
  getProductionUniqueWorkInfosForTest() async {
    if (!kDebugMode) return const [];
    final raw = await _channel.invokeMethod<List<Object?>>(
      'getProductionUniqueWorkInfosForTest',
    );
    return _decodeWorkInfos(raw);
  }

  static List<Map<String, Object?>> _decodeWorkInfos(List<Object?>? raw) {
    if (raw == null) return const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(
          (entry) => <String, Object?>{
            for (final kv in entry.entries)
              if (kv.key is String) kv.key as String: kv.value,
          },
        )
        .toList(growable: false);
  }

  Future<void> armTestCommitPause(String stage) async {
    if (!kDebugMode) return;
    await _channel.invokeMethod<void>(
      'armTestCommitPause',
      _scopedArgs({'stage': stage}),
    );
  }

  Future<bool> waitForTestCommitPause({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!kDebugMode) return false;
    return await _channel.invokeMethod<bool>(
          'waitForTestCommitPause',
          _scopedArgs({'timeoutMs': timeout.inMilliseconds}),
        ) ??
        false;
  }

  Future<void> awaitTestCommitRelease(String stage) async {
    if (!kDebugMode) return;
    await _channel.invokeMethod<void>(
      'awaitTestCommitRelease',
      _scopedArgs({'stage': stage}),
    );
  }

  Future<void> releaseTestCommitPause() async {
    if (!kDebugMode) return;
    await _channel.invokeMethod<void>(
      'releaseTestCommitPause',
      _optionalScopedArgs(),
    );
  }

  Future<void> clearTestHooks() async {
    if (!kDebugMode) return;
    final args = _optionalScopedArgs();
    _databaseName = null;
    _storageNamespace = null;
    _uniqueWorkName = null;
    await _channel.invokeMethod<void>('clearTestHooks', args);
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onBackupStateChanged' && !_externalChanges.isClosed) {
      _externalChanges.add(null);
    }
    return null;
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _externalChanges.close();
  }
}

class _PlatformRunLease implements BackupRunLease {
  _PlatformRunLease(this._onRelease);

  final Future<void> Function() _onRelease;
  bool _released = false;

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _onRelease();
  }
}
