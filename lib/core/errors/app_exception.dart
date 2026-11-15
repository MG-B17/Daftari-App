/// Closed codes and messages: never attach raw errors, user input, or PII.
enum AppErrorCode {
  database('database_error', 'The database operation failed.'),
  storage('storage_error', 'The preference operation failed.'),
  network('network_error', 'The network operation failed.'),
  auth('auth_error', 'Authentication failed.'),
  validation('validation_error', 'The input is invalid.'),
  unexpected('unexpected_error', 'An unexpected error occurred.');

  const AppErrorCode(this.code, this.message);

  final String code;
  final String message;
}

sealed class AppException implements Exception {
  const AppException(this.errorCode);

  final AppErrorCode errorCode;
  String get code => errorCode.code;
  String get message => errorCode.message;

  @override
  String toString() => '$code: $message';
}

final class DatabaseException extends AppException {
  const DatabaseException() : super(AppErrorCode.database);
}

final class StorageException extends AppException {
  const StorageException() : super(AppErrorCode.storage);
}

final class NetworkException extends AppException {
  const NetworkException() : super(AppErrorCode.network);
}

final class AuthException extends AppException {
  const AuthException() : super(AppErrorCode.auth);
}

final class ValidationException extends AppException {
  const ValidationException() : super(AppErrorCode.validation);
}

final class UnexpectedException extends AppException {
  const UnexpectedException() : super(AppErrorCode.unexpected);
}
