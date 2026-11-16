import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'all known exceptions map to Equatable failures without reporting',
    () async {
      final output = <String>[];
      final handler = ErrorHandler(AppLogger(output: output.add));
      for (final exception in <AppException>[
        const DatabaseException(),
        const StorageException(),
        const NetworkException(),
        const AuthException(),
        const ValidationException(),
      ]) {
        final failure = await handler.handle(exception);
        expect(failure, AppFailure(exception.errorCode));
        expect(failure.hashCode, AppFailure.fromException(exception).hashCode);
        expect(failure.code, exception.code);
        expect(failure.message, exception.message);
        expect(exception.toString(), '${exception.code}: ${exception.message}');
      }
      expect(output, isEmpty);
      expect(
        const AppFailure(AppErrorCode.auth),
        isNot(const AppFailure(AppErrorCode.network)),
      );
    },
  );

  test(
    'unexpected errors become safe failures and non-fatal reports',
    () async {
      final output = <String>[];
      var reports = 0;
      final handler = ErrorHandler(
        AppLogger(
          output: output.add,
          enableCrashReporting: true,
          crashReporter: (error, stack, {required fatal}) async {
            expect(fatal, isFalse);
            expect(error.code, 'unexpected_error');
            expect(stack.toString(), isEmpty);
            reports++;
          },
        ),
      );
      for (final error in [
        StateError('Ahmed 01012345678 owes 1250 EGP'),
        const UnexpectedException(),
      ]) {
        final failure = await handler.handle(error);
        expect(failure, const AppFailure(AppErrorCode.unexpected));
        expect(failure.toString(), isNot(contains('Ahmed')));
      }
      expect(reports, 2);
      expect(output, ['unexpected_error', 'unexpected_error']);
    },
  );
}
