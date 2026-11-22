import 'package:equatable/equatable.dart';

import '../../../session/presentation/cubit/auth_session_state.dart';

final class LoginState extends Equatable {
  const LoginState({
    this.busy = false,
    this.feedback = AuthFeedback.none,
    this.feedbackId = 0,
  });

  final bool busy;
  final AuthFeedback feedback;
  final int feedbackId;

  LoginState copyWith({bool? busy, AuthFeedback? feedback, int? feedbackId}) =>
      LoginState(
        busy: busy ?? this.busy,
        feedback: feedback ?? this.feedback,
        feedbackId: feedbackId ?? this.feedbackId,
      );

  @override
  List<Object?> get props => [busy, feedback, feedbackId];
}
