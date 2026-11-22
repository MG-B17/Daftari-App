import 'package:equatable/equatable.dart';

import 'auth_user.dart';

sealed class AuthOutcome extends Equatable {
  const AuthOutcome();

  @override
  List<Object?> get props => [];
}

final class AuthSignedIn extends AuthOutcome {
  const AuthSignedIn({required this.user});

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

final class AuthEmailVerificationRequired extends AuthOutcome {
  const AuthEmailVerificationRequired({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

final class AuthLinkConfirmationRequired extends AuthOutcome {
  const AuthLinkConfirmationRequired({
    required this.user,
    required this.hasLocalData,
  });

  final AuthUser user;
  final bool hasLocalData;

  @override
  List<Object?> get props => [user, hasLocalData];
}

final class AuthAccountMismatchBlocked extends AuthOutcome {
  const AuthAccountMismatchBlocked();
}
