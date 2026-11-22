import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../session/domain/entities/auth_user.dart';

abstract interface class VerifyEmailRepository {
  bool get isConfigured;

  Future<Either<AppFailure, void>> resendVerificationEmail(String email);

  Future<Either<AppFailure, AuthUser?>> getCurrentUser();
}
