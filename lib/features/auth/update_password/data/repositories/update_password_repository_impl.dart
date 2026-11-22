import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/app_failure.dart';
import '../../../session/data/services/auth_error_mapper.dart';
import '../../../session/data/services/supabase_auth_service.dart';
import '../../domain/repositories/update_password_repository.dart';

class UpdatePasswordRepositoryImpl implements UpdatePasswordRepository {
  const UpdatePasswordRepositoryImpl(this._authService, this._errorMapper);

  final AuthService _authService;
  final AuthErrorMapper _errorMapper;

  @override
  bool get isConfigured => _authService.isConfigured;

  @override
  Future<Either<AppFailure, void>> updatePassword(String newPassword) =>
      _errorMapper.guard(() => _authService.updatePassword(newPassword));
}
