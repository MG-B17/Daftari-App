import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../session/domain/repositories/auth_session_coordinator.dart';
import '../../../session/presentation/cubit/auth_session_state.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import 'sign_up_state.dart';

class SignUpCubit extends Cubit<SignUpState> {
  SignUpCubit(this._signUp, this._sessionCoordinator)
    : super(const SignUpState());

  final SignUpUseCase _signUp;
  final AuthSessionCoordinator _sessionCoordinator;

  Future<void> signUp({
    required String email,
    required String password,
    required String shopName,
  }) async {
    if (!_ensureConfigured() || state.busy) return;
    final token = _sessionCoordinator.beginAuthAction(email: email);
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    try {
      final result = await _signUp(
        email: email,
        password: password,
        shopName: shopName,
      );
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
