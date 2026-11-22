import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';

abstract interface class UpdatePasswordRepository {
  bool get isConfigured;

  Future<Either<AppFailure, void>> updatePassword(String newPassword);
}
