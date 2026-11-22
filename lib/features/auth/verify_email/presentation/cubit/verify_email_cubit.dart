import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../session/domain/repositories/auth_session_coordinator.dart';
import '../../../session/presentation/cubit/auth_session_state.dart';
import '../../domain/usecases/check_email_verified_usecase.dart';
import '../../domain/usecases/resend_verification_email_usecase.dart';
import 'verify_email_state.dart';

class VerifyEmailCubit extends Cubit<VerifyEmailState> {
  VerifyEmailCubit(
    this._resendVerificationEmail,
    this._checkEmailVerified,
    this._sessionCoordinator,
  ) : super(const VerifyEmailState());

  final ResendVerificationEmailUseCase _resendVerificationEmail;
  final CheckEmailVerifiedUseCase _checkEmailVerified;
  final AuthSessionCoordinator _sessionCoordinator;

  Future<void> resendVerificationEmail(String email) async {
    final trimmed = email.trim();
    if (!_ensureConfigured() || state.busy || trimmed.isEmpty) return;
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    final result = await _resendVerificationEmail(trimmed);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          busy: false,
          feedback: mapAuthFailureToFeedback(failure),
          feedbackId: state.feedbackId + 1,
        ),
      ),
      (_) => emit(
        state.copyWith(
          busy: false,
          feedback: AuthFeedback.verificationResent,
          feedbackId: state.feedbackId + 1,
        ),
      ),
    );
  }

  Future<void> checkEmailVerified({String? email}) async {
    if (!_ensureConfigured() || state.busy) return;
    final token = _sessionCoordinator.beginAuthAction(
      email: email ?? _sessionCoordinator.pendingEmail,
    );
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    try {
      final result = await _checkEmailVerified();
      result.fold(
        (failure) {
          if (isClosed) return;
          if (!_sessionCoordinator.isActionCurrent(token)) {
            emit(state.copyWith(busy: false));
            return;
          }
          emit(
            state.copyWith(
              busy: false,
              feedback: mapAuthFailureToFeedback(failure),
              feedbackId: state.feedbackId + 1,
            ),
          );
        },
        (outcome) {
          if (outcome == null) {
            if (isClosed) return;
            if (!_sessionCoordinator.isActionCurrent(token)) {
              emit(state.copyWith(busy: false));
              return;
            }
            emit(
              state.copyWith(
                busy: false,
                feedback: AuthFeedback.emailNotVerifiedYet,
                feedbackId: state.feedbackId + 1,
              ),
            );
            return;
          }
          if (!isClosed) emit(state.copyWith(busy: false));
          _sessionCoordinator.applyAuthOutcome(token, outcome);
        },
      );
    } finally {
      _sessionCoordinator.endAuthAction(token);
    }
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
