import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/restore_entities.dart';
import '../../domain/repositories/restore_repository.dart';
import 'restore_state.dart';

/// Coordinates cloud restore inspection, version-bound single/double consent,
/// device takeover, and interrupted transfer recovery.
class RestoreCubit extends Cubit<RestoreViewState> {
  RestoreCubit({
    required RestoreRepository repository,
    bool isPreview = false,
    FutureOr<void> Function()? onRestoreCompleted,
  }) : this._(repository, isPreview, onRestoreCompleted);

  RestoreCubit._(this._repository, bool isPreview, this._onRestoreCompleted)
    : super(RestoreViewState(isPreview: isPreview));

  final RestoreRepository _repository;
  final FutureOr<void> Function()? _onRestoreCompleted;
  int _feedbackSequence = 0;
  int _consumedFeedbackId = 0;

  bool consumeFeedback(int feedbackId) {
    if (feedbackId <= _consumedFeedbackId) return false;
    _consumedFeedbackId = feedbackId;
    return true;
  }

  /// Loads or refreshes the current restore eligibility, local ledger summary,
  /// interrupted transfer state, and server-confirmed cloud snapshot preview.
  Future<void> loadPreview() => _loadPreviewInternal();

  Future<void> _loadPreviewInternal({
    RestoreFeedback feedback = RestoreFeedback.none,
    bool allowWhenCancelling = false,
  }) async {
    if (isClosed) return;
    final busyWithoutCancel =
        state.phase == RestorePhase.loading ||
        state.phase == RestorePhase.executing;
    if (busyWithoutCancel ||
        (!allowWhenCancelling && state.isCancellingInterrupted)) {
      return;
    }

    emit(
      state.copyWith(
        phase: RestorePhase.loading,
        primaryConfirmed: false,
        replacementConfirmed: false,
        isCancellingInterrupted: false,
        refreshReason: () => null,
        feedback: RestoreFeedback.none,
      ),
    );

    final result = await _repository.inspectRestore();
    if (isClosed) return;

    final nextFeedbackId = feedback != RestoreFeedback.none
        ? ++_feedbackSequence
        : state.feedbackId;

    result.fold(
      (_) => emit(
        state.copyWith(
          phase: RestorePhase.error,
          primaryConfirmed: false,
          replacementConfirmed: false,
          isCancellingInterrupted: false,
          feedback: feedback,
          feedbackId: nextFeedbackId,
        ),
      ),
      (inspection) => _applyInspectionResult(
        inspection,
        feedback: feedback,
        feedbackId: nextFeedbackId,
      ),
    );
  }

  void _applyInspectionResult(
    RestoreInspectionResult result, {
    required RestoreFeedback feedback,
    required int feedbackId,
  }) {
    switch (result) {
      case RestoreInspectionSignedOut():
        emit(
          RestoreViewState(
            phase: RestorePhase.signedOut,
            isPreview: state.isPreview,
            feedback: feedback,
            feedbackId: feedbackId,
          ),
        );
      case RestoreInspectionEmailUnverified(:final email, :final shopName):
        emit(
          RestoreViewState(
            phase: RestorePhase.emailNotVerified,
            account: RestoreAccountInfo(
              userId: '',
              email: email,
              shopName: shopName,
              isEmailVerified: false,
            ),
            isPreview: state.isPreview,
            feedback: feedback,
            feedbackId: feedbackId,
          ),
        );
      case RestoreInspectionAccountMismatch(:final account, :final localLedger):
        emit(
          RestoreViewState(
            phase: RestorePhase.accountMismatch,
            account: account,
            localLedger: localLedger,
            isPreview: state.isPreview,
            feedback: feedback,
            feedbackId: feedbackId,
          ),
        );
      case RestoreInspectionOffline(
        :final account,
        :final localLedger,
        :final pendingTransfer,
      ):
        emit(
          RestoreViewState(
            phase: RestorePhase.offline,
            account: account,
            localLedger: localLedger,
            pendingTransfer: pendingTransfer,
            cloudPreview: pendingTransfer?.cloudPreview,
            isPreview: state.isPreview,
            feedback: feedback,
            feedbackId: feedbackId,
          ),
        );
      case RestoreInspectionMissingBackup(:final account, :final localLedger):
        emit(
          RestoreViewState(
            phase: RestorePhase.missingBackup,
            account: account,
            localLedger: localLedger,
            isPreview: state.isPreview,
            feedback: feedback,
            feedbackId: feedbackId,
          ),
        );
      case RestoreInspectionInterruptedTransfer(
        :final account,
        :final localLedger,
        :final pendingTransfer,
      ):
        emit(
          RestoreViewState(
            phase: RestorePhase.interruptedRecovery,
            account: account,
            localLedger: localLedger,
            pendingTransfer: pendingTransfer,
            cloudPreview: pendingTransfer.cloudPreview,
            isPreview: state.isPreview,
            feedback: feedback,
            feedbackId: feedbackId,
          ),
        );
      case RestoreInspectionReady(
        :final account,
        :final localLedger,
        :final cloudPreview,
      ):
        emit(
          RestoreViewState(
            phase: RestorePhase.previewReady,
            account: account,
            localLedger: localLedger,
            cloudPreview: cloudPreview,
            isPreview: state.isPreview,
            feedback: feedback,
            feedbackId: feedbackId,
          ),
        );
    }
  }

  /// Enters the primary confirmation step (combined restore + takeover on a new
  /// phone, or restore confirmation on the existing active phone).
  void requestRestoreConfirmation() {
    if (isClosed || state.phase != RestorePhase.previewReady || state.isBusy) {
      return;
    }
    if (state.account == null ||
        state.localLedger == null ||
        state.cloudPreview == null) {
      return;
    }
    emit(
      state.copyWith(
        phase: RestorePhase.confirmingPrimary,
        primaryConfirmed: false,
        replacementConfirmed: false,
        refreshReason: () => null,
        feedback: RestoreFeedback.none,
      ),
    );
  }

  /// Cancels either the primary or second replacement confirmation, leaving the
  /// local ledger and device authority untouched.
  void cancelConfirmation() {
    if (isClosed || state.isBusy) return;
    if (state.phase != RestorePhase.confirmingPrimary &&
        state.phase != RestorePhase.confirmingReplacement) {
      return;
    }
    emit(
      state.copyWith(
        phase: RestorePhase.previewReady,
        primaryConfirmed: false,
        replacementConfirmed: false,
        feedback: RestoreFeedback.none,
      ),
    );
  }

  /// Records the primary confirmation.
  ///
  /// When the local ledger is empty, this single confirmation permits and
  /// starts the restore (and device takeover if on a new phone).
  /// When the local ledger is populated (including tombstones or audit history),
  /// this advances to the second explicit replacement confirmation without
  /// executing the restore yet.
  Future<void> confirmPrimary() async {
    if (isClosed ||
        state.phase != RestorePhase.confirmingPrimary ||
        state.isBusy) {
      return;
    }

    if (state.requiresReplacement) {
      emit(
        state.copyWith(
          phase: RestorePhase.confirmingReplacement,
          primaryConfirmed: true,
          replacementConfirmed: false,
          feedback: RestoreFeedback.none,
        ),
      );
      return;
    }

    final consentedState = state.copyWith(
      primaryConfirmed: true,
      replacementConfirmed: false,
      feedback: RestoreFeedback.none,
    );
    await _executeConsentedRestore(consentedState);
  }

  /// Records the second explicit replacement confirmation for a populated local
  /// ledger and executes the restore.
  Future<void> confirmReplacement() async {
    if (isClosed ||
        state.phase != RestorePhase.confirmingReplacement ||
        !state.primaryConfirmed ||
        state.isBusy) {
      return;
    }
    final consentedState = state.copyWith(
      primaryConfirmed: true,
      replacementConfirmed: true,
      feedback: RestoreFeedback.none,
    );
    await _executeConsentedRestore(consentedState);
  }

  Future<void> _executeConsentedRestore(RestoreViewState consentedState) async {
    final token = consentedState.buildConsentToken();
    if (token == null || !token.isFullyPermitted) {
      emit(
        state.copyWith(
          phase: RestorePhase.previewReady,
          primaryConfirmed: false,
          replacementConfirmed: false,
          feedback: RestoreFeedback.none,
        ),
      );
      return;
    }

    emit(
      consentedState.copyWith(
        phase: RestorePhase.executing,
        feedback: RestoreFeedback.none,
      ),
    );

    try {
      final result = await _repository.executeRestore(consent: token);
      if (isClosed) return;

      await result.fold((failure) async {
        emit(
          consentedState.copyWith(
            phase: RestorePhase.error,
            primaryConfirmed: false,
            replacementConfirmed: false,
            feedback: _mapFailureFeedback(failure.errorCode),
            feedbackId: ++_feedbackSequence,
          ),
        );
      }, _applyExecutionResult);
    } catch (_) {
      if (isClosed) return;
      emit(
        consentedState.copyWith(
          phase: RestorePhase.error,
          primaryConfirmed: false,
          replacementConfirmed: false,
          feedback: RestoreFeedback.failed,
          feedbackId: ++_feedbackSequence,
        ),
      );
    }
  }

  /// Resumes a previously interrupted restore/device transfer using the same
  /// persisted request ID and expected version.
  Future<void> resumeInterruptedTransfer() async {
    if (isClosed ||
        state.phase != RestorePhase.interruptedRecovery ||
        state.isBusy) {
      return;
    }
    final inFlight = state.pendingTransfer;
    if (inFlight == null) return;

    emit(
      state.copyWith(
        phase: RestorePhase.executing,
        feedback: RestoreFeedback.none,
      ),
    );

    try {
      final result = await _repository.resumePendingTransfer(inFlight);
      if (isClosed) return;

      await result.fold((failure) async {
        emit(
          state.copyWith(
            phase: RestorePhase.interruptedRecovery,
            feedback: _mapFailureFeedback(failure.errorCode),
            feedbackId: ++_feedbackSequence,
          ),
        );
      }, _applyExecutionResult);
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: RestorePhase.interruptedRecovery,
          feedback: RestoreFeedback.failed,
          feedbackId: ++_feedbackSequence,
        ),
      );
    }
  }

  /// Cancels a pre-takeover interrupted transfer and refreshes the preview.
  Future<void> cancelInterruptedTransfer() async {
    if (isClosed ||
        state.phase != RestorePhase.interruptedRecovery ||
        state.isBusy) {
      return;
    }
    final inFlight = state.pendingTransfer;
    if (inFlight == null || !inFlight.canCancelBeforeServerTakeover) return;

    emit(
      state.copyWith(
        isCancellingInterrupted: true,
        feedback: RestoreFeedback.none,
      ),
    );
    try {
      final result = await _repository.discardPendingTransfer(
        inFlight.requestId,
      );
      if (isClosed) return;
      final failureFeedback = result.fold<RestoreFeedback>(
        (failure) => _mapFailureFeedback(failure.errorCode),
        (_) => RestoreFeedback.none,
      );
      await _loadPreviewInternal(
        feedback: failureFeedback,
        allowWhenCancelling: true,
      );
    } catch (_) {
      if (isClosed) return;
      await _loadPreviewInternal(
        feedback: RestoreFeedback.failed,
        allowWhenCancelling: true,
      );
    }
  }

  Future<void> _applyExecutionResult(RestoreExecutionResult result) async {
    switch (result) {
      case RestoreExecutionSucceeded(
        :final account,
        :final cloudPreview,
        :final localLedger,
        :final authorityTransferred,
      ):
        try {
          await _onRestoreCompleted?.call();
        } catch (_) {
          // Best-effort backup state refresh after restore already committed.
        }
        if (isClosed) return;
        emit(
          state.copyWith(
            phase: RestorePhase.completed,
            account: () => account,
            localLedger: () => localLedger,
            cloudPreview: () => cloudPreview,
            pendingTransfer: () => null,
            authorityTransferred: authorityTransferred,
            primaryConfirmed: false,
            replacementConfirmed: false,
            refreshReason: () => null,
            feedback: authorityTransferred
                ? RestoreFeedback.completedTransferred
                : RestoreFeedback.completedSameDevice,
            feedbackId: ++_feedbackSequence,
          ),
        );
      case RestoreExecutionCloudVersionChanged(
        :final account,
        :final localLedger,
        :final updatedCloudPreview,
      ):
        emit(
          state.copyWith(
            phase: RestorePhase.previewReady,
            account: () => account,
            localLedger: () => localLedger,
            cloudPreview: () => updatedCloudPreview,
            pendingTransfer: () => null,
            primaryConfirmed: false,
            replacementConfirmed: false,
            refreshReason: () =>
                RestoreRefreshReason.cloudVersionOrDeviceChanged,
            feedback: RestoreFeedback.cloudVersionChanged,
            feedbackId: ++_feedbackSequence,
          ),
        );
      case RestoreExecutionLocalLedgerChanged(
        :final account,
        :final updatedLocalLedger,
        :final cloudPreview,
      ):
        emit(
          state.copyWith(
            phase: RestorePhase.previewReady,
            account: () => account,
            localLedger: () => updatedLocalLedger,
            cloudPreview: () => cloudPreview,
            pendingTransfer: () => null,
            primaryConfirmed: false,
            replacementConfirmed: false,
            refreshReason: () => RestoreRefreshReason.localLedgerChanged,
            feedback: RestoreFeedback.localLedgerChanged,
            feedbackId: ++_feedbackSequence,
          ),
        );
      case RestoreExecutionBlockedAccountMismatch(
        :final account,
        :final localLedger,
      ):
        emit(
          state.copyWith(
            phase: RestorePhase.accountMismatch,
            account: () => account,
            localLedger: () => localLedger,
            pendingTransfer: () => null,
            primaryConfirmed: false,
            replacementConfirmed: false,
            refreshReason: () => null,
            feedback: RestoreFeedback.accountMismatch,
            feedbackId: ++_feedbackSequence,
          ),
        );
      case RestoreExecutionOffline(
        :final account,
        :final localLedger,
        :final pendingTransfer,
      ):
        emit(
          state.copyWith(
            phase: RestorePhase.offline,
            account: () => account,
            localLedger: () => localLedger,
            pendingTransfer: () => pendingTransfer,
            primaryConfirmed: false,
            replacementConfirmed: false,
            refreshReason: () => null,
            feedback: RestoreFeedback.offline,
            feedbackId: ++_feedbackSequence,
          ),
        );
      case RestoreExecutionInterrupted(
        :final account,
        :final localLedger,
        :final pendingTransfer,
      ):
        emit(
          state.copyWith(
            phase: RestorePhase.interruptedRecovery,
            account: () => account,
            localLedger: () => localLedger,
            pendingTransfer: () => pendingTransfer,
            cloudPreview: () => pendingTransfer.cloudPreview,
            primaryConfirmed: false,
            replacementConfirmed: false,
            refreshReason: () => null,
            feedback: RestoreFeedback.interrupted,
            feedbackId: ++_feedbackSequence,
          ),
        );
    }
  }

  static RestoreFeedback _mapFailureFeedback(AppErrorCode code) =>
      switch (code) {
        AppErrorCode.network => RestoreFeedback.offline,
        AppErrorCode.auth => RestoreFeedback.authError,
        AppErrorCode.database ||
        AppErrorCode.storage ||
        AppErrorCode.contactPicker ||
        AppErrorCode.validation ||
        AppErrorCode.unexpected => RestoreFeedback.failed,
      };
}
