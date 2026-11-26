import 'package:equatable/equatable.dart';

import '../../../session/presentation/cubit/auth_session_state.dart';

enum UpdatePasswordPendingAction { none, update, cancel }

final class UpdatePasswordState extends Equatable {
  const UpdatePasswordState({
    this.pendingAction = UpdatePasswordPendingAction.none,
    this.feedback = AuthFeedback.none,
    this.feedbackId = 0,
  });

  final UpdatePasswordPendingAction pendingAction;
  final AuthFeedback feedback;
  final int feedbackId;

  bool get busy => pendingAction != UpdatePasswordPendingAction.none;
  bool get isUpdating => pendingAction == UpdatePasswordPendingAction.update;
  bool get isCancelling => pendingAction == UpdatePasswordPendingAction.cancel;

  UpdatePasswordState copyWith({
    UpdatePasswordPendingAction? pendingAction,
    AuthFeedback? feedback,
    int? feedbackId,
  }) => UpdatePasswordState(
    pendingAction: pendingAction ?? this.pendingAction,
    feedback: feedback ?? this.feedback,
    feedbackId: feedbackId ?? this.feedbackId,
  );

  @override
  List<Object?> get props => [pendingAction, feedback, feedbackId];
}
