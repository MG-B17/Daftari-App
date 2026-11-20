import 'dart:ui';

import 'package:fpdart/fpdart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../domain/entities/share_statement_result.dart';

typedef StatementUrlLauncher = Future<bool> Function(
  Uri uri, {
  required LaunchMode mode,
});
typedef StatementSystemShare = Future<ShareResult> Function(ShareParams params);

class StatementShareService {
  StatementShareService(
    this._errors, {
    StatementUrlLauncher? launcher,
    StatementSystemShare? systemShare,
  }) : _launcher = launcher ?? _launch,
       _systemShare = systemShare ?? SharePlus.instance.share;

  static const maxWhatsAppUriLength = 4000;
  final ErrorHandler _errors;
  final StatementUrlLauncher _launcher;
  final StatementSystemShare _systemShare;

  static Future<bool> _launch(Uri uri, {required LaunchMode mode}) =>
      launchUrl(uri, mode: mode);

  static String? normalizePhone(String? phone) {
    if (phone == null) return null;
    var number = phone.trim();
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    for (var i = 0; i < 10; i++) {
      number = number.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
    }
    number = number.replaceAll(RegExp(r'[\s()-]'), '');
    if (number.startsWith('+')) {
      number = number.substring(1);
    } else if (number.startsWith('00')) {
      number = number.substring(2);
    }
    if (RegExp(r'^01[0125][0-9]{8}$').hasMatch(number)) {
      return '2$number';
    }
    if (RegExp(r'^201[0125][0-9]{8}$').hasMatch(number)) return number;
    return null;
  }

  Future<Either<AppFailure, ShareStatementResult>> shareViaWhatsApp({
    required String text,
    String? phone,
    Rect? sharePositionOrigin,
  }) async {
    if (text.trim().isEmpty) {
      return const Left(AppFailure(AppErrorCode.validation));
    }
    final number = normalizePhone(phone);
    if (number != null) {
      final uri = Uri(
        scheme: 'whatsapp',
        host: 'send',
        query: 'phone=$number&text=${Uri.encodeComponent(text)}',
      );
      if (uri.toString().length <= maxWhatsAppUriLength) {
        try {
          if (await _launcher(uri, mode: LaunchMode.externalApplication)) {
            // Opening the composer does not confirm message delivery.
            return const Right(ShareStatementResult.whatsapp);
          }
        } catch (_) {
          // Plugin errors may contain the full URI. Never log them.
        }
      }
    }
    return shareViaSystem(text: text, sharePositionOrigin: sharePositionOrigin);
  }

  Future<Either<AppFailure, ShareStatementResult>> shareViaSystem({
    required String text,
    Rect? sharePositionOrigin,
  }) async {
    if (text.trim().isEmpty) {
      return const Left(AppFailure(AppErrorCode.validation));
    }
    try {
      final result = await _systemShare(
        ShareParams(text: text, sharePositionOrigin: sharePositionOrigin),
      );
      return Right(
        result.status == ShareResultStatus.dismissed
            ? ShareStatementResult.dismissed
            : ShareStatementResult.systemShare,
      );
    } catch (_) {
      // Discard platform messages, raw results, and stacks containing private data.
      return Left(await _errors.handle(const UnexpectedException()));
    }
  }
}
