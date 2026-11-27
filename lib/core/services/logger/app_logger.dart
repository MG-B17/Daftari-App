import 'package:flutter/foundation.dart';

import '../../errors/app_exception.dart';

enum AppLogEvent { appStarted, preferencesUpdated, connectivityChanged }

typedef CrashReporter = Future<void> Function(
  UnexpectedException error,
  StackTrace stackTrace, {
  required bool fatal,
});

/// Intentionally accepts no free-form messages, metadata, or customer values.
///
/// Raw errors (including their type, message, and stack) are discarded. A closed
/// event vocabulary is safer than heuristic phone/amount redaction.
class AppLogger {
  AppLogger({
    void Function(String)? output,
    this._crashReporter,
    this.enableCrashReporting = kReleaseMode,
  }) : _output = output ?? _debugOutput;

  final void Function(String) _output;
  final CrashReporter? _crashReporter;
  final bool enableCrashReporting;

  void log(AppLogEvent event) => _emit(event.name);

  Future<void> recordError(Object error, {bool fatal = false}) async {
    _emit(AppErrorCode.unexpected.code);
    if (!enableCrashReporting || _crashReporter == null) return;
    try {
      await _crashReporter(
        const UnexpectedException(),
        StackTrace.empty,
        fatal: fatal,
      );
    } catch (_) {
      // Reporting must never mask the original operation or recursively log it.
      _emit('crash_reporting_failed');
    }
  }

  void _emit(String tag) {
    try {
      _output(tag);
    } catch (_) {
      // A failing log sink must not break application error handling.
    }
  }

  static void _debugOutput(String tag) {
    if (kDebugMode) debugPrint(tag);
  }
}
