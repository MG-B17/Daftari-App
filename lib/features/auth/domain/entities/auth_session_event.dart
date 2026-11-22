import 'package:equatable/equatable.dart';

import '../../../../core/errors/app_failure.dart';
import 'auth_user.dart';

sealed class AuthSessionEvent extends Equatable {
  const AuthSessionEvent();

  @override
  List<Object?> get props => [];
}

final class AuthSessionSignedIn extends AuthSessionEvent {
  const AuthSessionSignedIn(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

final class AuthSessionSignedOut extends AuthSessionEvent {
  const AuthSessionSignedOut();
}

final class AuthSessionPasswordRecovery extends AuthSessionEvent {
  const AuthSessionPasswordRecovery(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

final class AuthSessionFailure extends AuthSessionEvent {
  const AuthSessionFailure(this.failure);

  final AppFailure failure;

  @override
  List<Object?> get props => [failure];
}
