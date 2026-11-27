import '../services/logger/app_logger.dart';
import 'app_exception.dart';
import 'app_failure.dart';

class ErrorHandler {
  const ErrorHandler(this._logger);

  final AppLogger _logger;

  Future<AppFailure> handle(Object error) async {
    if (error is AppException && error is! UnexpectedException) {
      return AppFailure.fromException(error);
    }
    await _logger.recordError(error);
    return const AppFailure(AppErrorCode.unexpected);
  }
}
