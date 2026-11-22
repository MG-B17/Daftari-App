import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../session/data/services/auth_error_mapper.dart';
import '../../../session/data/services/supabase_auth_service.dart';
import '../../domain/repositories/forgot_password_repository.dart';

class ForgotPasswordRepositoryImpl implements ForgotPasswordRepository {
  const ForgotPasswordRepositoryImpl(this._authService, this._errorMapper);

  final AuthService _authService;
  final AuthErrorMapper _errorMapper;

  @override
  bool get isConfigured => _authService.isConfigured;

  @override
  Future<Either<AppFailure, void>> sendPasswordResetEmail(String email) =>
      _errorMapper.guard(() => _authService.sendPasswordResetEmail(email));
}
