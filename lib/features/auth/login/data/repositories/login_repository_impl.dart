import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../../core/errors/app_failure.dart';
import '../../../session/data/services/auth_error_mapper.dart';
import '../../../session/data/services/supabase_auth_service.dart';
import '../../../session/domain/entities/auth_user.dart';
import '../../domain/repositories/login_repository.dart';

class LoginRepositoryImpl implements LoginRepository {
  const LoginRepositoryImpl(this._authService, this._errorMapper);

  final AuthService _authService;
  final AuthErrorMapper _errorMapper;

  @override
  bool get isConfigured => _authService.isConfigured;

  @override
  Future<Either<AppFailure, AuthUser>> signInWithPassword({
    required String email,
    required String password,
  }) => _errorMapper.guard(() async {
    try {
      return await _authService.signInWithPassword(
        email: email,
        password: password,
      );
    } on sb.AuthException catch (error) {
      if (SupabaseAuthService.isEmailNotConfirmedError(error)) {
        return AuthUser(id: '', email: email, emailVerified: false);
      }
      rethrow;
    }
  });
}
