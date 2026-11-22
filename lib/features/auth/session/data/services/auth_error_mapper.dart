import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/errors/error_handler.dart';

/// Shared single-owner error mapper for all auth data adapters and session
/// streams. Never leaks provider messages, emails, or tokens across the
/// repository boundary.
class AuthErrorMapper {
  const AuthErrorMapper(this._errorHandler);

  final ErrorHandler _errorHandler;

  Future<Either<AppFailure, T>> guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } catch (error) {
      return Left(await mapError(error));
    }
  }

  Future<AppFailure> mapError(Object error) {
    if (error is AppException) return _errorHandler.handle(error);
    if (error is sb.AuthRetryableFetchException ||
        error is SocketException ||
        error is TimeoutException) {
      return _errorHandler.handle(const NetworkException());
    }
    if (error is sb.AuthException) {
      return _errorHandler.handle(const AuthException());
    }
    return _errorHandler.handle(error);
  }
}
