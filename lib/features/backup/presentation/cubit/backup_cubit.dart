import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/date/date_service.dart';
import '../../../auth/session/domain/entities/auth_user.dart';
import '../../../auth/session/presentation/cubit/auth_session_state.dart';
import '../../domain/entities/backup_eligibility.dart';
import '../../domain/entities/backup_run_result.dart';
import '../../domain/entities/backup_schedule.dart';
import '../../domain/policies/backup_eligibility_policy.dart';
import '../../domain/policies/backup_schedule_policy.dart';
import '../../domain/repositories/backup_local_store.dart';
import '../../domain/repositories/backup_run_lock.dart';
import '../../domain/repositories/backup_scheduler.dart';
import '../../domain/usecases/run_backup_usecase.dart';
import '../../domain/usecases/update_backup_schedule_usecase.dart';
import '../models/backup_view_state.dart';

/// App-wide Cubit coordinating live backup status, schedule selection,
/// manual **Back up now**, WorkManager schedule synchronization, and
/// foreground overdue retries (on launch, resume, auth sign-in, and
/// connectivity restoration).
class BackupCubit extends Cubit<BackupViewState> {
  BackupCubit({
    required RunBackupUseCase runBackup,
    required UpdateBackupScheduleUseCase updateSchedule,
    required BackupLocalStore localStore,
    required BackupScheduler scheduler,
    required BackupRunLock runLock,
    required DateService dateService,
    required AuthSessionState Function() readAuthState,
    required Stream<AuthSessionState> authStateStream,
    required Stream<bool> connectivityStream,
    Stream<void>? localChangesStream,
    Stream<void>? externalChangesStream,
    Future<bool> Function()? checkRemoteRunLocked,
  }) : this._(
         runBackup,
         updateSchedule,
         localStore,
         scheduler,
         runLock,
         dateService,
         readAuthState,
         authStateStream,
         connectivityStream,
         localChangesStream,
         externalChangesStream,
         checkRemoteRunLocked,
       );

  BackupCubit._(
    this._runBackup,
    this._updateSchedule,
    this._localStore,
    this._scheduler,
    this._runLock,
    this._dateService,
    this._readAuthState,
    this._authStateStream,
    this._connectivityStream,
    this._localChangesStream,
    this._externalChangesStream,
    this._checkRemoteRunLocked,
  ) : super(
        const BackupViewState(
          status: BackupStatus.neverBackedUp,
          pendingChanges: 0,
          isPreview: false,
          isEligibleForManualBackup: false,
        ),
      );

  final RunBackupUseCase _runBackup;
  final UpdateBackupScheduleUseCase _updateSchedule;
  final BackupLocalStore _localStore;
  final BackupScheduler _scheduler;
  final BackupRunLock _runLock;
  final DateService _dateService;
  final AuthSessionState Function() _readAuthState;
  final Stream<AuthSessionState> _authStateStream;
  final Stream<bool> _connectivityStream;
  final Stream<void>? _localChangesStream;
  final Stream<void>? _externalChangesStream;
  final Future<bool> Function()? _checkRemoteRunLocked;

  final List<StreamSubscription<Object?>> _subscriptions = [];

  Future<void>? _initializing;
  bool _manualRunning = false;
  bool _scheduledRunning = false;
  bool _lastAttemptFailed = false;
  bool _pendingScheduleSync = false;
  int _consumedManualFeedbackId = 0;
  BackupManualFeedback? _pendingManualFeedback;
  Future<void>? _refreshLoop;
  bool _refreshRequested = false;

  bool hasUnconsumedManualFeedback(int feedbackId) =>
      feedbackId > _consumedManualFeedbackId;

  bool consumeManualFeedback(int feedbackId) {
    if (feedbackId <= _consumedManualFeedbackId) return false;
    _consumedManualFeedbackId = feedbackId;
    return true;
  }

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    _subscriptions.add(
      _authStateStream.listen((authState) {
        if (isClosed) return;
        unawaited(_onAuthStateChanged(authState));
      }, onError: (_) {}),
    );
    _subscriptions.add(
      _connectivityStream.listen((connected) {
        if (isClosed) return;
        unawaited(_onConnectivityChanged(connected));
      }, onError: (_) {}),
    );
    if (_localChangesStream case final localStream?) {
      _subscriptions.add(
        localStream.listen((_) {
          if (isClosed) return;
          unawaited(refresh());
        }, onError: (_) {}),
      );
    }
    if (_externalChangesStream case final externalStream?) {
      _subscriptions.add(
        externalStream.listen((_) {
          if (isClosed) return;
          unawaited(refresh());
        }, onError: (_) {}),
      );
    }

    await refresh();
    if (isClosed) return;

    final scheduleResult = await _localStore.readScheduleState();
    if (isClosed) return;
    await scheduleResult.fold((_) async {}, (scheduleState) async {
      await _syncScheduleSafely(scheduleState, now: _dateService.now());
    });

    if (!isClosed) {
      unawaited(runScheduledIfDue());
    }
  }

  Future<void> _onAuthStateChanged(AuthSessionState authState) async {
    await refresh();
    if (isClosed) return;
    if (authState.isAuthenticated) {
      await runScheduledIfDue();
    }
  }

  Future<void> _onConnectivityChanged(bool connected) async {
    await refresh();
    if (isClosed) return;
    if (connected) {
      await runScheduledIfDue();
    }
  }

  /// Refreshes local status, eligibility and account display, and retries any
  /// overdue scheduled backup when returning to the foreground.
  Future<void> onAppResumed() async {
    if (isClosed) return;
    await refresh();
    if (isClosed) return;
    await runScheduledIfDue();
  }

  /// Re-reads persisted schedule metadata, pending ledger count, eligibility,
  /// and remote worker lock state, emitting an up-to-date [BackupViewState].
  ///
  /// Coalesces overlapping triggers sequentially so awaiting [refresh] always
  /// completes with the latest persisted snapshot emitted.
  Future<void> refresh() {
    if (isClosed) return Future<void>.value();
    _refreshRequested = true;
    return _refreshLoop ??= _drainRefreshes();
  }

  Future<void> _drainRefreshes() async {
    try {
      while (_refreshRequested && !isClosed) {
        _refreshRequested = false;
        await _performRefresh();
      }
    } finally {
      _refreshLoop = null;
    }
  }

  Future<void> _performRefresh() async {
    if (isClosed) return;

    final scheduleResult = await _localStore.readScheduleState();
    final eligibilityResult = await _localStore.readEligibilityContext();
    final remoteLocked = await _isRemoteLocked();

    if (isClosed) return;

    final scheduleState = scheduleResult.getOrElse(
      (_) => BackupScheduleState(
        schedule: state.schedule,
        lastConfirmedAt: state.lastConfirmedAt,
        nextDueAt: state.schedule != null
            ? BackupSchedulePolicy.nextDueAfter(
                state.lastConfirmedAt ?? _dateService.now(),
                state.schedule!,
              )
            : null,
      ),
    );
    if (_pendingScheduleSync && scheduleResult.isRight()) {
      await _syncScheduleSafely(scheduleState, now: _dateService.now());
      if (isClosed) return;
    }
    final eligibility = eligibilityResult.fold<BackupEligibilityContext?>(
      (_) => null,
      (value) => value,
    );

    final authState = _readAuthState();
    final AuthUser? visibleUser = authState.isAuthenticated
        ? authState.user
        : null;

    final isRunning = _manualRunning || _scheduledRunning || remoteLocked;
    final pendingCount =
        eligibility?.pendingChangesCount ?? state.pendingChanges;
    final canBackUpNow = eligibility == null
        ? false
        : BackupEligibilityPolicy.canBackUpNow(
            context: eligibility.copyWith(isBackupRunning: isRunning),
            scheduleState: scheduleState,
            now: _dateService.now(),
          );

    final status = _resolveStatus(
      isRunning: isRunning,
      lastAttemptFailed: _lastAttemptFailed,
      lastConfirmedAt: scheduleState.lastConfirmedAt,
      pendingChanges: pendingCount,
    );
    final isInactiveDevice =
        eligibility != null &&
        eligibility.isMatchingLinkedAccount &&
        eligibility.hasDeviceId &&
        !eligibility.isActiveDevice;
    final pendingFeedback = _pendingManualFeedback;
    _pendingManualFeedback = null;
    final nextManualFeedback = pendingFeedback ?? state.manualFeedback;
    final nextManualFeedbackId = pendingFeedback != null
        ? state.manualFeedbackId + 1
        : state.manualFeedbackId;

    emit(
      BackupViewState(
        status: status,
        pendingChanges: pendingCount,
        schedule: scheduleState.schedule,
        lastConfirmedAt: scheduleState.lastConfirmedAt,
        accountEmail: visibleUser?.email,
        accountShopName: visibleUser?.shopName,
        isPreview: false,
        isEligibleForManualBackup: canBackUpNow,
        isInactiveDevice: isInactiveDevice,
        manualFeedback: nextManualFeedback,
        manualFeedbackId: nextManualFeedbackId,
      ),
    );
  }

  /// Persists the selected schedule interval, replaces the single active
  /// Android WorkManager schedule, and triggers immediate overdue catch-up if
  /// the new schedule is already due.
  Future<void> selectSchedule(BackupSchedule schedule) async {
    if (isClosed) return;
    final result = await _updateSchedule(schedule);
    if (isClosed) return;
    await result.fold(
      (_) async {
        await refresh();
      },
      (saved) async {
        final now = _dateService.now();
        await _syncScheduleSafely(saved, now: now);
        await refresh();
        if (!isClosed && BackupSchedulePolicy.isDue(saved, now)) {
          unawaited(runScheduledIfDue());
        }
      },
    );
  }

  /// Runs a manual **Back up now** operation through the shared
  /// [RunBackupUseCase].
  Future<void> backUpNow() async {
    if (isClosed || _manualRunning) return;
    _manualRunning = true;
    _pendingManualFeedback = null;
    emit(
      state.copyWith(
        status: BackupStatus.running,
        isEligibleForManualBackup: false,
        manualFeedback: BackupManualFeedback.none,
      ),
    );

    try {
      if (_scheduledRunning || await _isRemoteLocked()) {
        if (isClosed) return;
        _pendingManualFeedback = BackupManualFeedback.alreadyRunning;
        return;
      }
      if (isClosed) return;
      _lastAttemptFailed = false;

      final result = await _runBackup(trigger: BackupTrigger.manual);
      if (isClosed) return;
      await result.fold(
        (failure) async {
          _lastAttemptFailed = true;
          _pendingManualFeedback = _mapFailureFeedback(failure.errorCode);
        },
        (runResult) async {
          switch (runResult) {
            case BackupRunConfirmed(:final scheduleState):
              _lastAttemptFailed = false;
              _pendingManualFeedback = BackupManualFeedback.confirmed;
              await _syncScheduleSafely(scheduleState, now: _dateService.now());
            case BackupRunSkipped(:final reason):
              _pendingManualFeedback = _mapSkippedFeedback(reason);
              final workerDecision = BackupWorkerPolicy.decide(result);
              if (workerDecision.shouldCancelSchedule) {
                await _cancelScheduleSafely();
              }
          }
        },
      );
    } catch (_) {
      _lastAttemptFailed = true;
      _pendingManualFeedback = BackupManualFeedback.failed;
    } finally {
      _manualRunning = false;
      if (!isClosed) {
        await refresh();
      }
    }
  }

  /// Executes a due or overdue scheduled backup in the foreground (e.g., on
  /// app launch, resume, sign-in, or connectivity return) using the exact same
  /// [RunBackupUseCase] as the Android background worker.
  Future<void> runScheduledIfDue() async {
    if (isClosed || _scheduledRunning || _manualRunning) return;
    if (await _isRemoteLocked()) return;

    final scheduleResult = await _localStore.readScheduleState();
    final scheduleState = scheduleResult.fold<BackupScheduleState?>(
      (_) => null,
      (value) => value,
    );
    final now = _dateService.now();
    if (scheduleState == null ||
        !BackupSchedulePolicy.isDue(scheduleState, now)) {
      return;
    }

    final eligibilityResult = await _localStore.readEligibilityContext();
    final eligibility = eligibilityResult.fold<BackupEligibilityContext?>(
      (_) => null,
      (value) => value,
    );
    if (eligibility == null) return;

    final decision = BackupEligibilityPolicy.evaluate(
      trigger: BackupTrigger.scheduled,
      context: eligibility,
      scheduleState: scheduleState,
      now: now,
    );

    // Advance an unchanged overdue schedule silently so it never loops, while
    // skipping other blocked states (offline/signed-out) without flashing UI.
    if (!decision.isEligible &&
        decision.reason != BackupIneligibilityReason.noPendingChanges) {
      return;
    }

    _scheduledRunning = true;
    final willUpload = decision.isEligible;
    if (willUpload && !isClosed) {
      _lastAttemptFailed = false;
      emit(
        state.copyWith(
          status: BackupStatus.running,
          isEligibleForManualBackup: false,
        ),
      );
    }

    try {
      final result = await _runBackup(trigger: BackupTrigger.scheduled);
      if (isClosed) return;
      final workerDecision = BackupWorkerPolicy.decide(result);
      if (workerDecision.shouldCancelSchedule) {
        await _cancelScheduleSafely();
      } else if (workerDecision.scheduleToSync case final nextSchedule?) {
        await _syncScheduleSafely(nextSchedule, now: _dateService.now());
      }
      result.fold(
        (_) {
          if (willUpload) {
            _lastAttemptFailed = true;
          }
        },
        (runResult) {
          if (runResult is BackupRunConfirmed) {
            _lastAttemptFailed = false;
          }
        },
      );
    } finally {
      _scheduledRunning = false;
      if (!isClosed) {
        await refresh();
      }
    }
  }

  Future<void> _syncScheduleSafely(
    BackupScheduleState scheduleState, {
    required DateTime now,
  }) async {
    try {
      await _scheduler.syncSchedule(scheduleState, now: now);
      _pendingScheduleSync = false;
    } catch (_) {
      _pendingScheduleSync = true;
    }
  }

  Future<void> _cancelScheduleSafely() async {
    try {
      await _scheduler.cancelScheduledBackup();
      _pendingScheduleSync = false;
    } catch (_) {
      _pendingScheduleSync = true;
    }
  }

  Future<bool> _isRemoteLocked() async {
    final check = _checkRemoteRunLocked;
    if (check != null) {
      try {
        return await check();
      } catch (_) {
        return _runLock.isLocked;
      }
    }
    return _runLock.isLocked;
  }

  static BackupStatus _resolveStatus({
    required bool isRunning,
    required bool lastAttemptFailed,
    required DateTime? lastConfirmedAt,
    required int pendingChanges,
  }) {
    if (isRunning) return BackupStatus.running;
    if (lastAttemptFailed) return BackupStatus.failed;
    if (lastConfirmedAt == null) return BackupStatus.neverBackedUp;
    if (pendingChanges > 0) return BackupStatus.pending;
    return BackupStatus.upToDate;
  }

  static BackupManualFeedback _mapFailureFeedback(AppErrorCode code) =>
      switch (code) {
        AppErrorCode.network => BackupManualFeedback.offline,
        AppErrorCode.auth => BackupManualFeedback.authError,
        AppErrorCode.database ||
        AppErrorCode.storage ||
        AppErrorCode.contactPicker ||
        AppErrorCode.validation ||
        AppErrorCode.unexpected => BackupManualFeedback.failed,
      };

  static BackupManualFeedback _mapSkippedFeedback(
    BackupIneligibilityReason reason,
  ) => switch (reason) {
    BackupIneligibilityReason.noPendingChanges =>
      BackupManualFeedback.nothingToUpload,
    BackupIneligibilityReason.alreadyRunning =>
      BackupManualFeedback.alreadyRunning,
    BackupIneligibilityReason.offline => BackupManualFeedback.offline,
    BackupIneligibilityReason.signedOut => BackupManualFeedback.signedOut,
    BackupIneligibilityReason.emailNotVerified =>
      BackupManualFeedback.emailNotVerified,
    BackupIneligibilityReason.ledgerUnlinked =>
      BackupManualFeedback.ledgerUnlinked,
    BackupIneligibilityReason.accountMismatch =>
      BackupManualFeedback.accountMismatch,
    BackupIneligibilityReason.inactiveDevice =>
      BackupManualFeedback.inactiveDevice,
    BackupIneligibilityReason.noScheduleConfigured ||
    BackupIneligibilityReason.notDueYet => BackupManualFeedback.failed,
  };

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    return super.close();
  }
}
