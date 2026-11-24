import 'dart:async';

import 'package:daftariapp/core/services/session_commit_gate.dart';
import 'package:daftariapp/features/backup/data/services/android_backup_platform_bridge.dart';
import 'package:daftariapp/features/backup/domain/entities/backup_schedule.dart';
import 'package:daftariapp/features/backup/domain/repositories/backup_scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-process simulation of Android's process-wide `BackupCoordinator` so
/// two independent `AndroidBackupPlatformBridge` + `SessionCommitGate`
/// instances (foreground and worker) can be tested against one shared
/// coordinator over MethodChannel.
class _FakeNativeBackupCoordinator {
  final List<MethodCall> calls = [];
  String? runLockOwner;
  int sessionEpoch = 0;
  int pendingInvalidations = 0;
  final Set<String> activeCommitOwners = {};
  final List<Completer<void>> invalidationWaiters = [];
  int? lastSyncedDelayMs;
  String? lastSyncedSchedule;
  int? lastSyncedNextDueAtEpochMs;
  String? lastWorkerSyncToken;
  int? lastWorkerSyncDelayMs;
  String? lastWorkerSyncSchedule;
  int? lastWorkerSyncNextDueAtEpochMs;
  String? lastWorkerCancelToken;
  int cancelCalls = 0;
  String? completedWorkerToken;
  String? completedWorkerOutcome;

  Future<Object?> handle(String ownerId, MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'syncSchedule':
        final args = call.arguments as Map<Object?, Object?>;
        lastSyncedDelayMs = (args['delayMs'] as num).toInt();
        lastSyncedSchedule = args['schedule'] as String?;
        lastSyncedNextDueAtEpochMs = (args['nextDueAtEpochMs'] as num?)
            ?.toInt();
        return null;
      case 'syncScheduleFromWorker':
        final args = call.arguments as Map<Object?, Object?>;
        lastWorkerSyncToken = args['token'] as String?;
        lastWorkerSyncDelayMs = (args['delayMs'] as num).toInt();
        lastWorkerSyncSchedule = args['schedule'] as String?;
        lastWorkerSyncNextDueAtEpochMs = (args['nextDueAtEpochMs'] as num?)
            ?.toInt();
        return null;
      case 'cancelScheduleFromWorker':
        final args = call.arguments as Map<Object?, Object?>;
        lastWorkerCancelToken = args['token'] as String?;
        return null;
      case 'cancelSchedule':
        cancelCalls++;
        return null;
      case 'tryAcquireRunLock':
        if (runLockOwner != null) return false;
        runLockOwner = ownerId;
        return true;
      case 'releaseRunLock':
        if (runLockOwner == ownerId) {
          runLockOwner = null;
        }
        return null;
      case 'isRunLocked':
        return runLockOwner != null;
      case 'readSessionEpoch':
        return sessionEpoch;
      case 'tryEnterCommit':
        final args = call.arguments as Map<Object?, Object?>;
        final expectedEpoch = (args['expectedEpoch'] as num).toInt();
        if (pendingInvalidations > 0 || sessionEpoch != expectedEpoch) {
          return false;
        }
        activeCommitOwners.add(ownerId);
        return true;
      case 'exitCommit':
        activeCommitOwners.remove(ownerId);
        if (activeCommitOwners.isEmpty) {
          final waiters = List<Completer<void>>.of(invalidationWaiters);
          invalidationWaiters.clear();
          for (final waiter in waiters) {
            if (!waiter.isCompleted) waiter.complete();
          }
        }
        return null;
      case 'beginSessionInvalidation':
        pendingInvalidations++;
        while (activeCommitOwners.isNotEmpty) {
          final waiter = Completer<void>();
          invalidationWaiters.add(waiter);
          await waiter.future;
        }
        return null;
      case 'endSessionInvalidation':
        sessionEpoch++;
        if (pendingInvalidations > 0) pendingInvalidations--;
        return null;
      case 'completeWorker':
        final args = call.arguments as Map<Object?, Object?>;
        completedWorkerToken = args['token'] as String?;
        completedWorkerOutcome = args['outcome'] as String?;
        return null;
      default:
        return null;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const foregroundChannel = MethodChannel('com.mgb.daftari/backup_fg_test');
  const workerChannel = MethodChannel('com.mgb.daftari/backup_worker_test');
  late _FakeNativeBackupCoordinator coordinator;
  late AndroidBackupPlatformBridge foregroundBridge;
  late AndroidBackupPlatformBridge workerBridge;

  setUp(() {
    coordinator = _FakeNativeBackupCoordinator();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          foregroundChannel,
          (call) => coordinator.handle('foreground', call),
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          workerChannel,
          (call) => coordinator.handle('worker', call),
        );
    foregroundBridge = AndroidBackupPlatformBridge(channel: foregroundChannel);
    workerBridge = AndroidBackupPlatformBridge(channel: workerChannel);
  });

  tearDown(() async {
    await foregroundBridge.dispose();
    await workerBridge.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(foregroundChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(workerChannel, null);
  });

  test(
    'syncSchedule computes delay, clamps overdue to 0, and cancels when unset',
    () async {
      final now = DateTime.utc(2026, 11, 24, 10);

      await foregroundBridge.syncSchedule(
        BackupScheduleState(
          schedule: BackupSchedule.daily,
          nextDueAt: now.add(const Duration(hours: 6)),
        ),
        now: now,
      );
      expect(
        coordinator.lastSyncedDelayMs,
        const Duration(hours: 6).inMilliseconds,
      );
      expect(coordinator.lastSyncedSchedule, 'daily');
      expect(
        coordinator.lastSyncedNextDueAtEpochMs,
        now.add(const Duration(hours: 6)).millisecondsSinceEpoch,
      );

      await foregroundBridge.syncSchedule(
        BackupScheduleState(
          schedule: BackupSchedule.daily,
          nextDueAt: now.subtract(const Duration(hours: 2)),
        ),
        now: now,
      );
      expect(coordinator.lastSyncedDelayMs, 0);

      await foregroundBridge.syncSchedule(
        const BackupScheduleState.initial(),
        now: now,
      );
      expect(coordinator.cancelCalls, 1);

      // P12-15: Worker successor scheduling uses syncScheduleFromWorker /
      // cancelScheduledBackupFromWorker so the running worker never replaces itself.
      final nextDue = now.add(const Duration(days: 1));
      await workerBridge.syncScheduleFromWorker(
        BackupScheduleState(schedule: BackupSchedule.daily, nextDueAt: nextDue),
        now: now,
        token: 'worker-99',
      );
      expect(coordinator.lastWorkerSyncToken, 'worker-99');
      expect(
        coordinator.lastWorkerSyncDelayMs,
        const Duration(days: 1).inMilliseconds,
      );
      expect(coordinator.lastWorkerSyncSchedule, 'daily');
      expect(
        coordinator.lastWorkerSyncNextDueAtEpochMs,
        nextDue.millisecondsSinceEpoch,
      );

      await workerBridge.syncScheduleFromWorker(
        const BackupScheduleState.initial(),
        now: now,
        token: 'worker-99',
      );
      expect(coordinator.lastWorkerCancelToken, 'worker-99');
    },
  );

  test(
    'run lock serializes foreground and background worker bridges',
    () async {
      final workerLease = await workerBridge.tryAcquire();
      expect(workerLease, isNotNull);
      expect(await foregroundBridge.refreshRemoteRunLocked(), isTrue);

      final overlappingForeground = await foregroundBridge.tryAcquire();
      expect(overlappingForeground, isNull);

      await workerLease!.release();
      expect(await foregroundBridge.refreshRemoteRunLocked(), isFalse);

      final fgLease = await foregroundBridge.tryAcquire();
      expect(fgLease, isNotNull);
      expect(await workerBridge.tryAcquire(), isNull);
      await fgLease!.release();
    },
  );

  test('cross-isolate SessionCommitGate serializes foreground sign-out after active worker commit', () async {
    final fgGate = SessionCommitGate(coordinator: foregroundBridge);
    final workerGate = SessionCommitGate(coordinator: workerBridge);

    final epoch = await workerGate.readEpoch();
    expect(await workerGate.tryEnterCommit(expectedEpoch: epoch), isTrue);

    var signOutCompleted = false;
    final signOutFuture = fgGate.runSessionInvalidation(() async {
      signOutCompleted = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(signOutCompleted, isFalse);

    await workerGate.exitCommit();
    await signOutFuture;
    expect(signOutCompleted, isTrue);
    expect(await workerGate.readEpoch(), epoch + 1);
  });

  test('cross-isolate SessionCommitGate rejects worker commit when foreground sign-out wins first', () async {
    final fgGate = SessionCommitGate(coordinator: foregroundBridge);
    final workerGate = SessionCommitGate(coordinator: workerBridge);

    final epochBeforeSignOut = await workerGate.readEpoch();
    await fgGate.runSessionInvalidation(() async {});

    expect(
      await workerGate.tryEnterCommit(expectedEpoch: epochBeforeSignOut),
      isFalse,
    );
  });

  test('forwards native state-change events and worker completion', () async {
    final events = <void>[];
    final sub = foregroundBridge.onExternalBackupStateChanged.listen(
      events.add,
    );
    addTearDown(sub.cancel);

    final codec = const StandardMethodCodec();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          foregroundChannel.name,
          codec.encodeMethodCall(const MethodCall('onBackupStateChanged')),
          (_) {},
        );
    expect(events.length, 1);

    await workerBridge.completeWorker(
      token: 'worker-42',
      outcome: BackupWorkerOutcome.retry,
    );
    expect(coordinator.completedWorkerToken, 'worker-42');
    expect(coordinator.completedWorkerOutcome, 'retry');
  });

  test(
    'falls back safely when no native channel handler is attached',
    () async {
      final detached = AndroidBackupPlatformBridge(
        channel: const MethodChannel('com.mgb.daftari/backup_detached_test'),
      );
      addTearDown(detached.dispose);

      final lease = await detached.tryAcquire();
      expect(lease, isNotNull);
      expect(detached.isLocked, isTrue);
      expect(await detached.tryAcquire(), isNull);
      await lease!.release();
      expect(detached.isLocked, isFalse);

      await detached.syncSchedule(
        BackupScheduleState(
          schedule: BackupSchedule.weekly,
          nextDueAt: DateTime.utc(2026, 12, 1),
        ),
        now: DateTime.utc(2026, 11, 24),
      );
      await detached.cancelScheduledBackup();
    },
  );

  test('binds isolated database, storage namespace and unique work queue per bridge instance without leaking into ordinary bridge calls (P12-17)', () async {
    final fixtureBridge = AndroidBackupPlatformBridge(
      channel: foregroundChannel,
    );
    final ordinaryBridge = AndroidBackupPlatformBridge(channel: workerChannel);
    addTearDown(fixtureBridge.dispose);
    addTearDown(ordinaryBridge.dispose);

    await fixtureBridge.configureTestEnvironment(
      databaseName: 'daftari_test_db',
      storageNamespace: 'daftari_test_ns',
      uniqueWorkName: 'com.mgb.daftari.cloud_backup.scheduled.test',
    );

    final now = DateTime.utc(2026, 11, 24, 12);
    await fixtureBridge.syncSchedule(
      BackupScheduleState(
        schedule: BackupSchedule.daily,
        nextDueAt: now.add(const Duration(days: 1)),
      ),
      now: now,
    );
    final fixtureSyncArgs =
        coordinator.calls.last.arguments as Map<Object?, Object?>;
    expect(
      fixtureSyncArgs['uniqueWorkName'],
      'com.mgb.daftari.cloud_backup.scheduled.test',
    );
    expect(fixtureSyncArgs['databaseName'], 'daftari_test_db');
    expect(fixtureSyncArgs['storageNamespace'], 'daftari_test_ns');

    await ordinaryBridge.syncSchedule(
      BackupScheduleState(
        schedule: BackupSchedule.weekly,
        nextDueAt: now.add(const Duration(days: 7)),
      ),
      now: now,
    );
    final ordinarySyncArgs =
        coordinator.calls.last.arguments as Map<Object?, Object?>;
    expect(ordinarySyncArgs.containsKey('uniqueWorkName'), isFalse);
    expect(ordinarySyncArgs.containsKey('databaseName'), isFalse);
    expect(ordinarySyncArgs.containsKey('storageNamespace'), isFalse);

    await fixtureBridge.clearTestHooks();
    await fixtureBridge.syncSchedule(
      BackupScheduleState(
        schedule: BackupSchedule.daily,
        nextDueAt: now.add(const Duration(days: 1)),
      ),
      now: now,
    );
    final clearedArgs =
        coordinator.calls.last.arguments as Map<Object?, Object?>;
    expect(clearedArgs.containsKey('uniqueWorkName'), isFalse);
  });
}
