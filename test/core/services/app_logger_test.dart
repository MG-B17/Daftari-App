import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

class PoisonError implements Exception {
  @override
  String toString() => throw StateError('Raw errors must not be inspected');
}

void main() {
  test(
    'only closed event tags and safe errors reach logs and reporter',
    () async {
      final output = <String>[];
      final reports = <UnexpectedException>[];
      final stacks = <StackTrace>[];
      final fatalFlags = <bool>[];
      final logger = AppLogger(
        output: output.add,
        enableCrashReporting: true,
        crashReporter: (error, stack, {required fatal}) async {
          reports.add(error);
          stacks.add(stack);
          fatalFlags.add(fatal);
        },
      );
      for (final event in AppLogEvent.values) {
        logger.log(event);
      }
      await logger.recordError(
        Exception('علي Ahmed 01012345678 ٠١٠١٢٣٤٥٦٧٨ 1250.50 ج.م EGP 99'),
      );
      await logger.recordError(PoisonError(), fatal: true);
      expect(output, [
        ...AppLogEvent.values.map((event) => event.name),
        'unexpected_error',
        'unexpected_error',
      ]);
      expect(reports, hasLength(2));
      expect(reports.map((error) => error.toString()).toSet(), {
        'unexpected_error: An unexpected error occurred.',
      });
      expect(stacks.every((stack) => stack.toString().isEmpty), isTrue);
      expect(fatalFlags, [false, true]);
      final combined = '${output.join()}${reports.join()}${stacks.join()}';
      for (final private in [
        'علي',
        'Ahmed',
        '01012345678',
        '٠١٠١٢٣٤٥٦٧٨',
        '1250.50',
        '99',
        'ج.م',
        'EGP',
        'PoisonError',
      ]) {
        expect(combined, isNot(contains(private)));
      }
    },
  );

  test('reporting can be disabled without losing safe console tags', () async {
    var calls = 0;
    final output = <String>[];
    final logger = AppLogger(
      output: output.add,
      enableCrashReporting: false,
      crashReporter: (error, stack, {required fatal}) async => calls++,
    );
    await logger.recordError(PoisonError());
    expect(calls, 0);
    expect(output, ['unexpected_error']);
  });

  test(
    'reporter and sink failures never escape or leak their messages',
    () async {
      final output = <String>[];
      final logger = AppLogger(
        output: output.add,
        enableCrashReporting: true,
        crashReporter: (error, stack, {required fatal}) async =>
            throw Exception('customer 01012345678 amount 100'),
      );
      await logger.recordError(PoisonError());
      expect(output, ['unexpected_error', 'crash_reporting_failed']);
      final brokenSink = AppLogger(
        output: (_) => throw StateError('private sink error'),
      );
      brokenSink.log(AppLogEvent.appStarted);
      await brokenSink.recordError(PoisonError());
    },
  );
}
