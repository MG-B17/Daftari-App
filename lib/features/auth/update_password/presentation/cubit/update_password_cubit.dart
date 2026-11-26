import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../session/domain/repositories/auth_session_coordinator.dart';
import '../../../session/presentation/cubit/auth_session_state.dart';
import '../../domain/usecases/update_password_usecase.dart';
import 'update_password_state.dart';

class UpdatePasswordCubit extends Cubit<UpdatePasswordState> {
  UpdatePasswordCubit(this._updatePassword, this._sessionCoordinator)
    : super(const UpdatePasswordState());

  final UpdatePasswordUseCase _updatePassword;
  final AuthSessionCoordinator _sessionCoordinator;

  bool get shouldNavigateToLoginAfterUpdate =>
      !_sessionCoordinator.isAuthenticated &&
      !_sessionCoordinator.requiresLinkConfirmation;

  Future<bool> updatePassword(String newPassword) async {
    if (!_ensureConfigured() || state.busy) return false;
    final token = _sessionCoordinator.beginAuthAction(
      userId: _sessionCoordinator.currentUserId,
    );
    emit(
      state.copyWith(
        pendingAction: UpdatePasswordPendingAction.update,
        feedback: AuthFeedback.none,
      ),
    );
    try {
      final result = await _updatePassword(newPassword);
      return await result.fold(
        (failure) async {
          if (isClosed) return false;
          if (!_sessionCoordinator.isActionCurrent(token)) {
            emit(
              state.copyWith(pendingAction: UpdatePasswordPendingAction.none),
            );
            return false;
          }
          emit(
            state.copyWith(
              pendingAction: UpdatePasswordPendingAction.none,
              feedback: mapAuthFailureToFeedback(failure),
              feedbackId: state.feedbackId + 1,
            ),
          );
          return false;
        },
        (_) async {
          final completed = await _sessionCoordinator.completePasswordRecovery(
            token,
          );
          if (!isClosed) {
            emit(
              state.copyWith(pendingAction: UpdatePasswordPendingAction.none),
            );
          }
          return completed;
        },
      );
    } finally {
      _sessionCoordinator.endAuthAction(token);
    }
  }

  Future<bool> cancelRecovery() async {
    if (state.busy) return false;
    emit(
      state.copyWith(
        pendingAction: UpdatePasswordPendingAction.cancel,
        feedback: AuthFeedback.none,
      ),
    );
    final cancelled = await _sessionCoordinator.cancelPasswordRecovery();
    if (!isClosed) {
      emit(state.copyWith(pendingAction: UpdatePasswordPendingAction.none));
    }
    return cancelled;
  }

  bool _ensureConfigured() {
    if (_sessionCoordinator.isConfigured) return true;
    emit(
      state.copyWith(
        feedback: AuthFeedback.unconfigured,
        feedbackId: state.feedbackId + 1,
      ),
    );
    return false;
  }
}
