import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../session/data/services/auth_error_mapper.dart';
import '../../../session/data/services/supabase_auth_service.dart';
import '../../../session/domain/entities/auth_user.dart';
import '../../domain/repositories/verify_email_repository.dart';

class VerifyEmailRepositoryImpl implements VerifyEmailRepository {
  const VerifyEmailRepositoryImpl(this._authService, this._errorMapper);

  final AuthService _authService;
  final AuthErrorMapper _errorMapper;

  @override
  bool get isConfigured => _authService.isConfigured;

  @override
  Future<Either<AppFailure, void>> resendVerificationEmail(String email) =>
      _errorMapper.guard(() => _authService.resendVerificationEmail(email));

  @override
  Future<Either<AppFailure, AuthUser?>> getCurrentUser() =>
      _errorMapper.guard(_authService.getCurrentUser);
}
