import 'dart:async';
import 'dart:ui';

import 'package:bloc_test/bloc_test.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/errors/error_handler.dart';
import 'package:daftariapp/core/services/app_logger.dart';
import 'package:daftariapp/core/utils/app_date_utils.dart';
import 'package:daftariapp/features/statements/data/services/statement_share_service.dart';
import 'package:daftariapp/features/statements/domain/entities/customer_statement_entity.dart';
import 'package:daftariapp/features/statements/domain/entities/share_statement_result.dart';
import 'package:daftariapp/features/statements/domain/entities/statement_date_range.dart';
import 'package:daftariapp/features/statements/domain/repositories/statement_repository.dart';
import 'package:daftariapp/features/statements/domain/usecases/get_customer_statement_usecase.dart';
import 'package:daftariapp/features/statements/presentation/cubit/statement_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/statement_fixtures.dart';
import '../../statement_image_fakes.dart';

typedef _StatementResult = Either<AppFailure, CustomerStatementEntity?>;

class _Repository implements StatementRepository {
  final requests = <({String id, StatementDateRange range})>[];
  Future<_StatementResult> Function(String, StatementDateRange)? handler;

  @override
  Future<_StatementResult> getCustomerStatement(
    String customerId, {
    StatementDateRange range = StatementDateRange.all,
  }) {
    requests.add((id: customerId, range: range));
    return handler?.call(customerId, range) ??
        Future.value(Right(statementFixture(range: range)));
  }
}

void main() {
  const failure = AppFailure(AppErrorCode.database);
  const origin = Rect.fromLTWH(10, 20, 30, 40);
  final statement = statementFixture(entries: [statementTransaction()]);
  late _Repository repository;
  late StatementShareService service;
  late List<Uri> launches;
  late List<ShareParams> shares;
  late List<String> logs;
  late FakeStatementImageRenderer renderer;
  late ShareResultStatus shareStatus;
  late bool shareThrows;
  Completer<ShareResult>? pendingShare;

  StatementCubit build() => StatementCubit(
    GetCustomerStatementUseCase(repository),
    service,
    renderer,
  );

  setUpAll(AppDateUtils.initialize);
  setUp(() {
    repository = _Repository();
    launches = [];
    shares = [];
    logs = [];
    renderer = FakeStatementImageRenderer();
    shareStatus = ShareResultStatus.success;
    shareThrows = false;
    pendingShare = null;
    service = MemoryStatementShareService(
      ErrorHandler(AppLogger(output: logs.add)),
      handler: (params) async {
        shares.add(params);
        if (shareThrows) throw StateError('PRIVATE statement and phone');
        return pendingShare?.future ?? ShareResult('', shareStatus);
      },
    );
  });

  test(
    'starts without fetching or sharing and state does not stringify data',
    () async {
      final cubit = build();
      addTearDown(cubit.close);
      expect(cubit.state, const StatementState());
      expect(cubit.state.canShare, isFalse);
      expect(cubit.state.notFound, isFalse);
      expect(repository.requests, isEmpty);
      expect(launches, isEmpty);
      expect(shares, isEmpty);
      expect(StatementState(statement: statement).stringify, isFalse);
      expect(
        StatementState(statement: statement).toString(),
        isNot(contains(statement.customer.name)),
      );
    },
  );

  blocTest<StatementCubit, StatementState>(
    'load emits loading then a snapshot; never shares automatically',
    build: build,
    setUp: () => repository.handler = (_, _) async => Right(statement),
    act: (cubit) => cubit.load('c1'),
    expect: () => [
      const StatementState(),
      StatementState(loading: false, statement: statement),
    ],
    verify: (cubit) {
      expect(repository.requests.single, (
        id: 'c1',
        range: StatementDateRange.all,
      ));
      expect(cubit.state.canShare, isTrue);
      expect(launches, isEmpty);
      expect(shares, isEmpty);
    },
  );

  blocTest<StatementCubit, StatementState>(
    'failure can be retried explicitly',
    build: build,
    act: (cubit) async {
      repository.handler = (_, _) async => const Left(failure);
      await cubit.load('c1');
      repository.handler = (_, _) async => Right(statement);
      await cubit.load('c1');
    },
    expect: () => [
      const StatementState(),
      const StatementState(loading: false, failure: failure),
      const StatementState(),
      StatementState(loading: false, statement: statement),
    ],
  );

  blocTest<StatementCubit, StatementState>(
    'missing or deleted customer is not found, not an error',
    build: build,
    setUp: () => repository.handler = (_, _) async => const Right(null),
    act: (cubit) => cubit.load('missing'),
    expect: () => [
      const StatementState(),
      const StatementState(loading: false),
    ],
    verify: (cubit) {
      expect(cubit.state.notFound, isTrue);
      expect(cubit.state.canShare, isFalse);
    },
  );

  blocTest<StatementCubit, StatementState>(
    'unexpected load exceptions become a safe failure',
    build: build,
    setUp: () => repository.handler = (_, _) => throw StateError('PRIVATE'),
    act: (cubit) => cubit.load('c1'),
    expect: () => [
      const StatementState(),
      const StatementState(
        loading: false,
        failure: AppFailure(AppErrorCode.unexpected),
      ),
    ],
    verify: (_) => expect(logs, isEmpty),
  );

  for (final range in [
    StatementDateRange.last30Days,
    StatementDateRange.thisMonth,
    StatementDateRange.custom(start: DateTime(2026, 1), end: DateTime(2026, 2)),
  ]) {
    blocTest<StatementCubit, StatementState>(
      'setRange reloads the current customer for ${range.type}',
      build: build,
      act: (cubit) async {
        await cubit.load('c1');
        await cubit.setRange(range);
        await cubit.setRange(range);
      },
      skip: 2,
      expect: () => [
        StatementState(range: range),
        StatementState(
          loading: false,
          range: range,
          statement: statementFixture(range: range),
        ),
      ],
      verify: (_) {
        expect(repository.requests, hasLength(2));
        expect(repository.requests.last, (id: 'c1', range: range));
      },
    );
  }

  test('a range selected before load is used by the first request', () async {
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.setRange(StatementDateRange.thisMonth);
    expect(repository.requests, isEmpty);
    await cubit.load('c1');
    expect(repository.requests.single.range, StatementDateRange.thisMonth);
  });

  test('newest load wins even when an older request fails later', () async {
    final pending = Completer<_StatementResult>();
    repository.handler = (id, range) =>
        id == 'old' ? pending.future : Future.value(Right(statement));
    final cubit = build();
    addTearDown(cubit.close);
    final old = cubit.load('old');
    await cubit.load('c1');
    pending.complete(const Left(failure));
    await old;
    expect(cubit.state.statement, statement);
    expect(cubit.state.failure, isNull);
  });

  test('rapid range changes ignore old successful snapshots', () async {
    final pending = Completer<_StatementResult>();
    final cubit = build();
    addTearDown(cubit.close);
    await cubit.load('c1');
    repository.handler = (_, range) => range == StatementDateRange.last30Days
        ? pending.future
        : Future.value(Right(statementFixture(range: range)));
    final old = cubit.setRange(StatementDateRange.last30Days);
    await cubit.setRange(StatementDateRange.thisMonth);
    pending.complete(
      Right(statementFixture(range: StatementDateRange.last30Days)),
    );
    await old;
    expect(cubit.state.range, StatementDateRange.thisMonth);
    expect(cubit.state.statement!.range, StatementDateRange.thisMonth);
  });

  test(
    'no share before load, while loading, on failure, or when not found',
    () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.shareViaWhatsApp();
      final pending = Completer<_StatementResult>();
      repository.handler = (_, _) => pending.future;
      final load = cubit.load('c1');
      await cubit.shareViaSystem();
      pending.complete(const Left(failure));
      await load;
      await cubit.shareViaWhatsApp();
      repository.handler = (_, _) async => const Right(null);
      await cubit.load('c1');
      await cubit.shareViaSystem();
      expect(launches, isEmpty);
      expect(shares, isEmpty);
    },
  );

  for (final locale in ['ar', 'en']) {
    blocTest<StatementCubit, StatementState>(
      'image renderer receives the exact $locale snapshot',
      build: build,
      setUp: () => repository.handler = (_, _) async => Right(statement),
      act: (cubit) async {
        await cubit.load('c1');
        await cubit.shareViaWhatsApp(locale: locale);
      },
      skip: 2,
      expect: () => [
        StatementState(loading: false, statement: statement, sharing: true),
        StatementState(
          loading: false,
          statement: statement,
          shareResult: ShareStatementResult.systemShare,
        ),
      ],
      verify: (_) {
        expect(renderer.requests.single, (
          statement: statement,
          locale: locale,
        ));
        expect(shares.single.text, isNull);
        expect(shares.single.files!.single.mimeType, 'image/png');
      },
    );
  }

  blocTest<StatementCubit, StatementState>(
    'system sharing renders filtered snapshot and preserves share-sheet origin',
    build: build,
    act: (cubit) async {
      await cubit.load('c1', range: StatementDateRange.thisMonth);
      await cubit.shareViaSystem(locale: 'en', sharePositionOrigin: origin);
    },
    skip: 2,
    expect: () => [
      isA<StatementState>().having((s) => s.sharing, 'sharing', true),
      isA<StatementState>()
          .having((s) => s.sharing, 'sharing', false)
          .having(
            (s) => s.shareResult,
            'result',
            ShareStatementResult.systemShare,
          ),
    ],
    verify: (cubit) {
      expect(launches, isEmpty);
      expect(shares.single.sharePositionOrigin, origin);
      expect(shares.single.text, isNull);
      expect(renderer.requests.single.statement, cubit.state.statement);
      expect(renderer.requests.single.locale, 'en');
    },
  );

  test(
    'WhatsApp action uses native image sharing and preserves origin',
    () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load('c1');
      await cubit.shareViaWhatsApp(sharePositionOrigin: origin);
      expect(cubit.state.shareResult, ShareStatementResult.systemShare);
      expect(shares.single.sharePositionOrigin, origin);
    },
  );

  for (final status in [
    ShareResultStatus.dismissed,
    ShareResultStatus.unavailable,
  ]) {
    test('system share $status is not treated as failure', () async {
      shareStatus = status;
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load('c1');
      await cubit.shareViaSystem();
      expect(cubit.state.shareFailure, isNull);
      expect(
        cubit.state.shareResult,
        status == ShareResultStatus.dismissed
            ? ShareStatementResult.dismissed
            : ShareStatementResult.systemShare,
      );
    });
  }

  test(
    'share failure retains snapshot, clears busy, and retry clears old outcome',
    () async {
      shareThrows = true;
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load('c1');
      final snapshot = cubit.state.statement;
      await cubit.shareViaSystem();
      expect(
        cubit.state.shareFailure,
        const AppFailure(AppErrorCode.unexpected),
      );
      expect(cubit.state.failure, isNull);
      expect(cubit.state.statement, same(snapshot));
      expect(cubit.state.canShare, isTrue);
      expect(logs.join(), isNot(contains('PRIVATE')));
      shareThrows = false;
      pendingShare = Completer<ShareResult>();
      final retry = cubit.shareViaSystem();
      expect(cubit.state.shareFailure, isNull);
      expect(cubit.state.shareResult, isNull);
      pendingShare!.complete(const ShareResult('', ShareResultStatus.success));
      await retry;
      expect(cubit.state.shareResult, ShareStatementResult.systemShare);
    },
  );

  test(
    'repeated share actions are serialized across both methods and reloads',
    () async {
      pendingShare = Completer<ShareResult>();
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load('c1');
      final pending = cubit.shareViaSystem();
      await cubit.shareViaWhatsApp();
      await cubit.shareViaSystem();
      await cubit.load('c1');
      await cubit.shareViaWhatsApp();
      expect(cubit.state.sharing, isTrue);
      expect(shares, hasLength(1));
      expect(launches, isEmpty);
      pendingShare!.complete(const ShareResult('', ShareResultStatus.success));
      await pending;
      expect(cubit.state.sharing, isFalse);
      expect(cubit.state.shareResult, isNull);
      await cubit.shareViaWhatsApp();
      expect(shares, hasLength(2));
    },
  );

  test(
    'stale share completion preserves a newer loading/error state',
    () async {
      pendingShare = Completer<ShareResult>();
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load('c1');
      final share = cubit.shareViaSystem();
      final request = Completer<_StatementResult>();
      repository.handler = (_, _) => request.future;
      final reload = cubit.setRange(StatementDateRange.last30Days);
      expect(cubit.state.statement, isNull);
      pendingShare!.complete(
        const ShareResult('', ShareResultStatus.dismissed),
      );
      await share;
      expect(cubit.state.loading, isTrue);
      expect(cubit.state.range, StatementDateRange.last30Days);
      expect(cubit.state.sharing, isFalse);
      expect(cubit.state.shareResult, isNull);
      request.complete(const Left(failure));
      await reload;
      expect(cubit.state.failure, failure);
    },
  );

  test('close suppresses pending loads and all subsequent commands', () async {
    final pending = Completer<_StatementResult>();
    repository.handler = (_, _) => pending.future;
    final cubit = build();
    final load = cubit.load('c1');
    await cubit.close();
    pending.complete(Right(statement));
    await load;
    await cubit.load('other');
    await cubit.setRange(StatementDateRange.thisMonth);
    await cubit.shareViaWhatsApp();
    await cubit.shareViaSystem();
    expect(repository.requests, hasLength(1));
    expect(shares, isEmpty);
    expect(launches, isEmpty);
  });

  test('close suppresses pending share completion', () async {
    pendingShare = Completer<ShareResult>();
    final cubit = build();
    await cubit.load('c1');
    final share = cubit.shareViaSystem();
    await cubit.close();
    final closedState = cubit.state;
    pendingShare!.complete(const ShareResult('', ShareResultStatus.success));
    await share;
    expect(cubit.state, closedState);
  });

  test(
    'async renderer stream failure is private, resets busy, and allows retry',
    () async {
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load('c1');
      renderer.throwsError = true;
      final share = cubit.shareViaSystem();
      expect(cubit.state.sharing, isTrue);
      expect(renderer.requests, isEmpty);
      await share;
      expect(renderer.requests, hasLength(1));
      expect(
        cubit.state.shareFailure,
        const AppFailure(AppErrorCode.unexpected),
      );
      expect(cubit.state.sharing, isFalse);
      expect(shares, isEmpty);
      expect(logs, isEmpty);
      renderer.throwsError = false;
      await cubit.shareViaSystem();
      expect(cubit.state.shareResult, ShareStatementResult.systemShare);
    },
  );
}
