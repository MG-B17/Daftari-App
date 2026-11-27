import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/logger/app_logger.dart';
import 'package:daftariapp/features/statements/data/services/statement_share_service.dart';
import 'package:daftariapp/features/statements/domain/entities/share_statement_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  late Directory directory;
  late List<String> logs;
  late List<ShareParams> shares;
  late StatementShareService service;
  var status = ShareResultStatus.success;
  var throwsError = false;
  final now = DateTime.now();
  Stream<Uint8List> pages() => Stream.fromIterable([
    Uint8List.fromList([137, 80, 78, 71]),
    Uint8List.fromList([1, 2, 3]),
  ]);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('statement-test-');
    logs = [];
    shares = [];
    status = ShareResultStatus.success;
    throwsError = false;
    service = StatementShareService(
      ErrorHandler(AppLogger(output: logs.add)),
      temporaryDirectory: directory,
      now: () => now,
      systemShare: (params) async {
        shares.add(params);
        for (final file in params.files!) {
          expect(await file.readAsBytes(), isNotEmpty);
        }
        if (throwsError) throw StateError('PRIVATE phone and note');
        return ShareResult('PRIVATE raw response', status);
      },
    );
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'shares ordered PNG files and origin without text; retains attachments',
    () async {
      const origin = Rect.fromLTWH(1, 2, 3, 4);
      final events = <String>[];
      final orderedService = StatementShareService(
        ErrorHandler(AppLogger(output: logs.add)),
        temporaryDirectory: directory,
        now: () => now,
        systemShare: (params) async {
          events.add('share');
          shares.add(params);
          for (final file in params.files!) {
            expect(await file.readAsBytes(), isNotEmpty);
          }
          return ShareResult('PRIVATE raw response', status);
        },
      );
      final result = await orderedService.shareImages(
        pages: pages(),
        sharePositionOrigin: origin,
        onPrepared: () => events.add('prepared'),
      );
      expect(
        result.getOrElse((_) => throw StateError('failure')),
        ShareStatementResult.handedOff,
      );
      expect(events, ['prepared', 'share']);
      final params = shares.single;
      expect(params.text, isNull);
      expect(params.sharePositionOrigin, origin);
      expect(params.files, hasLength(2));
      expect(params.files!.map((f) => f.mimeType), everyElement('image/png'));
      expect(await params.files!.first.readAsBytes(), [137, 80, 78, 71]);
      expect(await params.files!.last.readAsBytes(), [1, 2, 3]);
      expect(await File(params.files!.first.path).exists(), isTrue);
    },
  );

  for (final value in [
    ShareResultStatus.dismissed,
    ShareResultStatus.unavailable,
  ]) {
    test('$value never claims delivery', () async {
      status = value;
      final result = await service.shareImages(pages: pages());
      expect(
        result.getOrElse((_) => throw StateError('failure')),
        value == ShareResultStatus.dismissed
            ? ShareStatementResult.dismissed
            : ShareStatementResult.systemShare,
      );
    });
  }

  test('padded filenames preserve lexicographic order for 12 pages', () async {
    final result = await service.shareImages(
      pages: Stream.fromIterable(
        List.generate(12, (i) => Uint8List.fromList([i + 1])),
      ),
    );
    expect(result.isRight(), isTrue);
    final files = shares.single.files!;
    final names = files.map((file) => file.name).toList();
    expect(names.first, 'statement-000001.png');
    expect(names.last, 'statement-000012.png');
    expect([...names]..sort(), orderedEquals(names));
    for (var i = 0; i < files.length; i++) {
      expect(await files[i].readAsBytes(), [i + 1]);
    }
  });

  test('share failure cleans batch and sanitizes errors', () async {
    throwsError = true;
    expect((await service.shareImages(pages: pages())).isLeft(), isTrue);
    expect(await directory.list().toList(), isEmpty);
    expect(logs.join(), isNot(contains('PRIVATE')));
  });

  test(
    'render failure cleans partial batch and never opens share sheet',
    () async {
      var prepared = false;
      Stream<Uint8List> broken() async* {
        yield Uint8List.fromList([1]);
        throw StateError('PRIVATE render error');
      }

      expect(
        (await service.shareImages(
          pages: broken(),
          onPrepared: () => prepared = true,
        )).isLeft(),
        isTrue,
      );
      expect(prepared, isFalse);
      expect(shares, isEmpty);
      expect(await directory.list().toList(), isEmpty);
    },
  );

  test('empty export fails safely', () async {
    var prepared = false;
    expect(
      (await service.shareImages(
        pages: const Stream.empty(),
        onPrepared: () => prepared = true,
      )).isLeft(),
      isTrue,
    );
    expect(prepared, isFalse);
    expect(shares, isEmpty);
    expect(await directory.list().toList(), isEmpty);
  });

  test('stale batches removed while recent attachments and unrelated files survive', () async {
    final old = await Directory.fromUri(directory.uri.resolve('export-old/'))
        .create();
    await File.fromUri(old.uri.resolve('old.png')).writeAsBytes([1]);
    final unrelated = await File.fromUri(directory.uri.resolve('unrelated'))
        .writeAsString('keep');
    final cleaner = StatementShareService(
      ErrorHandler(AppLogger(output: logs.add)),
      temporaryDirectory: directory,
      now: () => now.add(const Duration(days: 2)),
      systemShare: (_) async =>
          const ShareResult('', ShareResultStatus.dismissed),
    );
    await cleaner.shareImages(pages: pages());
    expect(await old.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
    final first = await service.shareImages(pages: pages());
    expect(first.isRight(), isTrue);
    final path = shares.last.files!.first.path;
    await service.shareImages(pages: pages());
    expect(await File(path).exists(), isTrue);
  });
}
