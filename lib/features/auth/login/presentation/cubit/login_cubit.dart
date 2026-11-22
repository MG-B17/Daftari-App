import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../session/domain/repositories/auth_session_coordinator.dart';
import '../../../session/presentation/cubit/auth_session_state.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._signIn, this._sessionCoordinator)
    : super(const LoginState());

  final SignInUseCase _signIn;
  final AuthSessionCoordinator _sessionCoordinator;

  Future<void> signIn({required String email, required String password}) async {
    if (!_ensureConfigured() || state.busy) return;
    final token = _sessionCoordinator.beginAuthAction(email: email);
    emit(state.copyWith(busy: true, feedback: AuthFeedback.none));
    try {
      final result = await _signIn(email: email, password: password);
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
