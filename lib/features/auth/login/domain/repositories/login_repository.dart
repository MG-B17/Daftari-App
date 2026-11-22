import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../session/domain/entities/auth_user.dart';

abstract interface class LoginRepository {
  bool get isConfigured;

  Future<Either<AppFailure, AuthUser>> signInWithPassword({
    required String email,
    required String password,
  });
}
