import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/features/statements/data/services/statement_share_service.dart';
import 'package:daftariapp/features/statements/domain/entities/customer_statement_entity.dart';
import 'package:daftariapp/features/statements/domain/entities/share_statement_result.dart';
import 'package:daftariapp/features/statements/presentation/services/statement_image_renderer.dart';
import 'package:fpdart/fpdart.dart';
import 'package:share_plus/share_plus.dart';

class FakeStatementImageRenderer implements StatementImageRenderer {
  final requests = <({CustomerStatementEntity statement, String locale})>[];
  bool throwsError = false;
  Completer<void>? pendingRender;

  @override
  Stream<Uint8List> render(
    CustomerStatementEntity statement, {
    required String locale,
  }) async* {
    requests.add((statement: statement, locale: locale));
    if (pendingRender != null) {
      await pendingRender!.future;
    }
    if (throwsError) throw StateError('PRIVATE renderer');
    yield Uint8List.fromList([137, 80, 78, 71]);
  }
}

class MemoryStatementShareService extends StatementShareService {
  MemoryStatementShareService(super.errors, {required this.handler});
  final StatementSystemShare handler;

  @override
  Future<Either<AppFailure, ShareStatementResult>> shareImages({
    required Stream<Uint8List> pages,
    Rect? sharePositionOrigin,
    VoidCallback? onPrepared,
  }) async {
    try {
      final files = <XFile>[];
      await for (final bytes in pages) {
        if (bytes.isEmpty) throw StateError('Empty statement image');
        final pageNumber = '${files.length + 1}'.padLeft(6, '0');
        files.add(XFile('statement-$pageNumber.png', mimeType: 'image/png'));
      }
      if (files.isEmpty) throw StateError('Empty statement export');
      onPrepared?.call();
      final result = await handler(
        ShareParams(files: files, sharePositionOrigin: sharePositionOrigin),
      );
      return Right(switch (result.status) {
        ShareResultStatus.success => ShareStatementResult.handedOff,
        ShareResultStatus.dismissed => ShareStatementResult.dismissed,
        ShareResultStatus.unavailable => ShareStatementResult.systemShare,
      });
    } catch (_) {
      return const Left(AppFailure(AppErrorCode.unexpected));
    }
  }
}
