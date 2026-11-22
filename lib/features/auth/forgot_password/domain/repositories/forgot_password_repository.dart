import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';

abstract interface class ForgotPasswordRepository {
  bool get isConfigured;

  Future<Either<AppFailure, void>> sendPasswordResetEmail(String email);
}
