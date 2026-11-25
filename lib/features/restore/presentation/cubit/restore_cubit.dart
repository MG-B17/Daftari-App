import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

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
  bool _isCancellingInterrupted = false;

  /// Loads or refreshes the current restore eligibility, local ledger summary,
  /// interrupted transfer state, and server-confirmed cloud snapshot preview.
  Future<void> loadPreview() async {
    if (isClosed) return;
    emit(
      state.copyWith(
        phase: RestorePhase.loading,
        primaryConfirmed: false,
        replacementConfirmed: false,
        refreshReason: () => null,
      ),
    );

    final result = await _repository.inspectRestore();
    if (isClosed) return;

    result.fold(
      (_) => emit(
        state.copyWith(
          phase: RestorePhase.error,
          primaryConfirmed: false,
          replacementConfirmed: false,
        ),
      ),
      _applyInspectionResult,
    );
  }

  void _applyInspectionResult(RestoreInspectionResult result) {
    switch (result) {
      case RestoreInspectionSignedOut():
        emit(
          RestoreViewState(
            phase: RestorePhase.signedOut,
            isPreview: state.isPreview,
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
          ),
        );
      case RestoreInspectionAccountMismatch(:final account, :final localLedger):
        emit(
          RestoreViewState(
            phase: RestorePhase.accountMismatch,
            account: account,
            localLedger: localLedger,
            isPreview: state.isPreview,
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
          ),
        );
      case RestoreInspectionMissingBackup(:final account, :final localLedger):
        emit(
          RestoreViewState(
            phase: RestorePhase.missingBackup,
            account: account,
            localLedger: localLedger,
            isPreview: state.isPreview,
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
          ),
        );
    }
  }

  /// Enters the primary confirmation step (combined restore + takeover on a new
  /// phone, or restore confirmation on the existing active phone).
  void requestRestoreConfirmation() {
    if (isClosed || state.phase != RestorePhase.previewReady) return;
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
      ),
    );
  }

  /// Cancels either the primary or second replacement confirmation, leaving the
  /// local ledger and device authority untouched.
  void cancelConfirmation() {
    if (isClosed) return;
    if (state.phase != RestorePhase.confirmingPrimary &&
        state.phase != RestorePhase.confirmingReplacement) {
      return;
    }
    emit(
      state.copyWith(
        phase: RestorePhase.previewReady,
        primaryConfirmed: false,
        replacementConfirmed: false,
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
    if (isClosed || state.phase != RestorePhase.confirmingPrimary) return;

    if (state.requiresReplacement) {
      emit(
        state.copyWith(
          phase: RestorePhase.confirmingReplacement,
          primaryConfirmed: true,
          replacementConfirmed: false,
        ),
      );
      return;
    }

    final consentedState = state.copyWith(
      primaryConfirmed: true,
      replacementConfirmed: false,
    );
    await _executeConsentedRestore(consentedState);
  }

  /// Records the second explicit replacement confirmation for a populated local
  /// ledger and executes the restore.
  Future<void> confirmReplacement() async {
    if (isClosed ||
        state.phase != RestorePhase.confirmingReplacement ||
        !state.primaryConfirmed) {
      return;
    }
    final consentedState = state.copyWith(
      primaryConfirmed: true,
      replacementConfirmed: true,
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
        ),
      );
      return;
    }

    emit(consentedState.copyWith(phase: RestorePhase.executing));

    final result = await _repository.executeRestore(consent: token);
    if (isClosed) return;

    await result.fold((_) async {
      emit(
        consentedState.copyWith(
          phase: RestorePhase.error,
          primaryConfirmed: false,
          replacementConfirmed: false,
        ),
      );
    }, _applyExecutionResult);
  }

  /// Resumes a previously interrupted restore/device transfer using the same
  /// persisted request ID and expected version.
  Future<void> resumeInterruptedTransfer() async {
    if (isClosed ||
        state.phase != RestorePhase.interruptedRecovery ||
        _isCancellingInterrupted) {
      return;
    }
    final inFlight = state.pendingTransfer;
    if (inFlight == null) return;

    emit(state.copyWith(phase: RestorePhase.executing));

    final result = await _repository.resumePendingTransfer(inFlight);
    if (isClosed) return;

    await result.fold((_) async {
      emit(state.copyWith(phase: RestorePhase.interruptedRecovery));
    }, _applyExecutionResult);
  }

  /// Cancels a pre-takeover interrupted transfer and refreshes the preview.
  Future<void> cancelInterruptedTransfer() async {
    if (isClosed ||
        state.phase != RestorePhase.interruptedRecovery ||
        _isCancellingInterrupted) {
      return;
    }
    final inFlight = state.pendingTransfer;
    if (inFlight == null || !inFlight.canCancelBeforeServerTakeover) return;

    _isCancellingInterrupted = true;
    try {
      final result = await _repository.discardPendingTransfer(
        inFlight.requestId,
      );
      if (isClosed) return;
      await result.fold((_) => loadPreview(), (_) => loadPreview());
    } finally {
      _isCancellingInterrupted = false;
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
          ),
        );
        await _onRestoreCompleted?.call();
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
          ),
        );
    }
  }
}
