import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../session/domain/repositories/auth_session_coordinator.dart';
import '../../../session/presentation/cubit/auth_session_state.dart';
import '../../domain/usecases/send_password_reset_usecase.dart';
import 'forgot_password_state.dart';

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit(this._sendPasswordReset, this._sessionCoordinator)
    : super(const ForgotPasswordState());

  final SendPasswordResetUseCase _sendPasswordReset;
  final AuthSessionCoordinator _sessionCoordinator;

  Future<bool> sendPasswordReset(String email) async {
    if (!_ensureConfigured() || state.busy) return false;
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    final result = await _sendPasswordReset(email);
    if (isClosed) return false;
    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            busy: false,
            feedback: mapAuthFailureToFeedback(failure),
            feedbackId: state.feedbackId + 1,
          ),
        );
        return false;
      },
      (_) {
        emit(
          state.copyWith(
            busy: false,
            sent: true,
            sentEmail: email.trim(),
            feedback: AuthFeedback.passwordResetSent,
            feedbackId: state.feedbackId + 1,
          ),
        );
        return true;
      },
    );
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
