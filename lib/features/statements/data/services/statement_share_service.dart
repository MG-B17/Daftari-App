import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:fpdart/fpdart.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_handler.dart';
import '../../domain/entities/share_statement_result.dart';

typedef StatementSystemShare = Future<ShareResult> Function(ShareParams params);

class StatementShareService {
  StatementShareService(
    this._errors, {
    StatementSystemShare? systemShare,
    Directory? temporaryDirectory,
    DateTime Function()? now,
  }) : _systemShare = systemShare ?? SharePlus.instance.share,
       _directory =
           temporaryDirectory ??
           Directory.fromUri(
             Directory.systemTemp.uri.resolve('daftari_statements/'),
           ),
       _now = now ?? DateTime.now;

  final ErrorHandler _errors;
  final StatementSystemShare _systemShare;
  final Directory _directory;
  final DateTime Function() _now;
  bool _busy = false;

  Future<Either<AppFailure, ShareStatementResult>> shareImages({
    required Stream<Uint8List> pages,
    Rect? sharePositionOrigin,
    VoidCallback? onPrepared,
  }) async {
    if (_busy) return const Left(AppFailure(AppErrorCode.validation));
    _busy = true;
    Directory? batch;
    try {
      await _directory.create(recursive: true);
      // Retain recent attachments: receivers may read them after share returns.
      final cutoff = _now().subtract(const Duration(days: 1));
      await for (final entity in _directory.list(followLinks: false)) {
        if (entity is Directory &&
            entity.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .last
                .startsWith('export-') &&
            (await entity.stat()).modified.isBefore(cutoff)) {
          await entity.delete(recursive: true);
        }
      }
      batch = await _directory.createTemp('export-');
      final files = <XFile>[];
      await for (final bytes in pages) {
        if (bytes.isEmpty) throw const UnexpectedException();
        final pageNumber = '${files.length + 1}'.padLeft(6, '0');
        final file = File.fromUri(
          batch.uri.resolve('statement-$pageNumber.png'),
        );
        await file.writeAsBytes(bytes, flush: true);
        files.add(XFile(file.path, mimeType: 'image/png'));
      }
      if (files.isEmpty) throw const UnexpectedException();
      onPrepared?.call();
      final result = await _systemShare(
        ShareParams(files: files, sharePositionOrigin: sharePositionOrigin),
      );
      return Right(switch (result.status) {
        ShareResultStatus.success => ShareStatementResult.handedOff,
        ShareResultStatus.dismissed => ShareStatementResult.dismissed,
        ShareResultStatus.unavailable => ShareStatementResult.systemShare,
      });
    } catch (_) {
      try {
        if (batch != null && await batch.exists()) {
          await batch.delete(recursive: true);
        }
      } catch (_) {
        // A later stale cleanup can retry. Never expose paths or private errors.
      }
      return Left(await _errors.handle(const UnexpectedException()));
    } finally {
      _busy = false;
    }
  }
}
