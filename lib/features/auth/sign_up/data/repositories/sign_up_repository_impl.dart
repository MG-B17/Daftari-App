import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../session/data/services/auth_error_mapper.dart';
import '../../../session/data/services/supabase_auth_service.dart';
import '../../../session/domain/entities/auth_user.dart';
import '../../domain/repositories/sign_up_repository.dart';

class SignUpRepositoryImpl implements SignUpRepository {
  const SignUpRepositoryImpl(this._authService, this._errorMapper);

  final AuthService _authService;
  final AuthErrorMapper _errorMapper;

  @override
  bool get isConfigured => _authService.isConfigured;

  @override
  Future<Either<AppFailure, AuthUser>> signUpWithPassword({
    required String email,
    required String password,
    required String shopName,
  }) => _errorMapper.guard(
    () => _authService.signUpWithPassword(
      email: email,
      password: password,
      shopName: shopName,
    ),
  );
}
