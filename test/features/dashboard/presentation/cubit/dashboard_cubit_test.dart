import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:daftariapp/core/errors/app_exception.dart';
import 'package:daftariapp/core/errors/app_failure.dart';
import 'package:daftariapp/core/services/date/date_service.dart';
import 'package:daftariapp/features/dashboard/domain/entities/dashboard_summary_entity.dart';
import 'package:daftariapp/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:daftariapp/features/dashboard/domain/usecases/watch_dashboard_summary_usecase.dart';
import 'package:daftariapp/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

class _DateService implements DateService {
  DateTime current = DateTime(2026, 11, 18, 12);

  @override
  DateTime now() => current;
}

class _Repository implements DashboardRepository {
  final controllers =
      <StreamController<Either<AppFailure, DashboardSummaryEntity>>>[];
  int cancellations = 0;
  bool throwsOnWatch = false;
  Completer<void>? cancellation;

  @override
  Stream<Either<AppFailure, DashboardSummaryEntity>> watchDashboardSummary() {
    if (throwsOnWatch) throw StateError('watch failed');
    final controller =
        StreamController<Either<AppFailure, DashboardSummaryEntity>>(
          sync: true,
          onCancel: () {
            cancellations++;
            return cancellation?.future;
          },
        );
    controllers.add(controller);
    return controller.stream;
  }

  Future<void> dispose() async {
    for (final controller in controllers) {
      await controller.close();
    }
  }
}

class _Timer implements Timer {
  _Timer(this.duration, this.callback);
  final Duration duration;
  final void Function() callback;
  bool _active = true;
  int _tick = 0;

  @override
  bool get isActive => _active;
  @override
  int get tick => _tick;
  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _active = false;
    _tick++;
    callback();
  }
}

class _Timers {
  final values = <_Timer>[];

  Future<void> run(Future<void> Function() action) => runZoned(
    action,
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        final timer = _Timer(duration, zone.bindCallback(callback));
        values.add(timer);
        return timer;
      },
    ),
  );
}

void main() {
  const summary = DashboardSummaryEntity.empty();
  const failure = AppFailure(AppErrorCode.storage);
  late _Repository repository;
  late _DateService dateService;

  DashboardCubit build() =>
      DashboardCubit(WatchDashboardSummaryUseCase(repository), dateService);

  setUp(() {
    repository = _Repository();
    dateService = _DateService();
  });
  tearDown(() => repository.dispose());

  test(
    'initial state is loading; construction does not start a watch',
    () async {
      final cubit = build();
      expect(cubit.state, const DashboardState());
      expect(repository.controllers, isEmpty);
      await cubit.close();
    },
  );

  blocTest<DashboardCubit, DashboardState>(
    'emits loading, summary, failure retaining summary, then recovers',
    build: build,
    act: (cubit) async {
      await cubit.refresh();
      final controller = repository.controllers.single;
      controller.add(const Right(summary));
      controller.add(const Left(failure));
      controller.add(const Right(summary));
    },
    expect: () => [
      const DashboardState(),
      const DashboardState(loading: false, summary: summary),
      const DashboardState(loading: false, summary: summary, failure: failure),
      const DashboardState(loading: false, summary: summary),
    ],
  );

  blocTest<DashboardCubit, DashboardState>(
    'handles raw stream errors and keeps listening for recovery',
    build: build,
    act: (cubit) async {
      await cubit.refresh();
      repository.controllers.single.addError(StateError('private details'));
      repository.controllers.single.add(const Right(summary));
    },
    expect: () => [
      const DashboardState(),
      const DashboardState(
        loading: false,
        failure: AppFailure(AppErrorCode.unexpected),
      ),
      const DashboardState(loading: false, summary: summary),
    ],
  );

  blocTest<DashboardCubit, DashboardState>(
    'maps a synchronously thrown watch and allows explicit retry',
    build: build,
    act: (cubit) async {
      repository.throwsOnWatch = true;
      await cubit.refresh();
      repository.throwsOnWatch = false;
      await cubit.refresh();
      repository.controllers.single.add(const Right(summary));
    },
    expect: () => [
      const DashboardState(),
      const DashboardState(
        loading: false,
        failure: AppFailure(AppErrorCode.unexpected),
      ),
      const DashboardState(),
      const DashboardState(loading: false, summary: summary),
    ],
  );

  blocTest<DashboardCubit, DashboardState>(
    'explicit same-day refresh replaces the watch and retains summary',
    build: build,
    act: (cubit) async {
      await cubit.refresh();
      repository.controllers.single.add(const Right(summary));
      await cubit.refresh();
      expect(repository.cancellations, 1);
      repository.controllers.first.add(const Left(failure));
      repository.controllers.last.add(const Right(summary));
    },
    expect: () => [
      const DashboardState(),
      const DashboardState(loading: false, summary: summary),
      const DashboardState(summary: summary),
      const DashboardState(loading: false, summary: summary),
    ],
    verify: (_) => expect(repository.controllers, hasLength(2)),
  );

  test(
    'same-day check is a no-op; an uninitialized check starts watching',
    () async {
      final cubit = build();
      await cubit.refreshIfDayChanged();
      repository.controllers.single.add(const Right(summary));
      dateService.current = DateTime(2026, 11, 18, 23);
      await cubit.refreshIfDayChanged();
      expect(repository.controllers, hasLength(1));
      expect(repository.cancellations, 0);
      expect(
        cubit.state,
        const DashboardState(loading: false, summary: summary),
      );
      await cubit.close();
    },
  );

  test('resume detects skipped days and backward calendar changes', () async {
    final cubit = build();
    await cubit.refresh();
    dateService.current = DateTime(2026, 12, 18, 12);
    await cubit.refreshIfDayChanged();
    dateService.current = DateTime(2026, 11, 18, 12);
    await cubit.refreshIfDayChanged();
    expect(repository.controllers, hasLength(3));
    expect(repository.cancellations, 2);
    await cubit.close();
  });

  test('one-shot timer refreshes at each calendar midnight', () async {
    final timers = _Timers();
    await timers.run(() async {
      dateService.current = DateTime(2026, 12, 31, 23, 59, 59);
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.refresh();
      expect(timers.values.single.duration, const Duration(seconds: 1));
      expect(repository.controllers, hasLength(1));
      dateService.current = DateTime(2027);
      timers.values.last.fire();
      await Future<void>.value();
      expect(repository.controllers, hasLength(2));
      expect(repository.cancellations, 1);
      expect(timers.values.last.duration, const Duration(days: 1));
      dateService.current = DateTime(2027, 1, 2);
      timers.values.last.fire();
      await Future<void>.value();
      expect(repository.controllers, hasLength(3));
      await cubit.close();
    });
  });

  test(
    'early timer after clock rollback rearms without resubscribing',
    () async {
      final timers = _Timers();
      await timers.run(() async {
        dateService.current = DateTime(2026, 11, 18, 23, 59, 59);
        final cubit = build();
        addTearDown(cubit.close);
        await cubit.refresh();
        dateService.current = DateTime(2026, 11, 18, 23);
        timers.values.last.fire();
        expect(repository.controllers, hasLength(1));
        expect(timers.values.last.duration, const Duration(hours: 1));
        dateService.current = DateTime(2026, 11, 19);
        timers.values.last.fire();
        await Future<void>.value();
        expect(repository.controllers, hasLength(2));
        await cubit.close();
      });
    },
  );

  test('explicit refresh replaces timer; close cancels all work', () async {
    final timers = _Timers();
    await timers.run(() async {
      dateService.current = DateTime.utc(2026, 11, 18, 23, 59, 59);
      final cubit = build();
      await cubit.refresh();
      // A resumed app refreshes before the old midnight timer is delivered.
      dateService.current = DateTime.utc(2026, 11, 19);
      await cubit.refreshIfDayChanged();
      expect(timers.values.first.isActive, isFalse);
      timers.values.first.fire();
      expect(repository.controllers, hasLength(2));
      await cubit.close();
      expect(repository.cancellations, 2);
      expect(timers.values.every((timer) => !timer.isActive), isTrue);
      dateService.current = DateTime.utc(2026, 11, 21);
      timers.values.last.fire();
      await cubit.refresh();
      await cubit.refreshIfDayChanged();
      expect(repository.controllers, hasLength(2));
    });
  });

  test('overlapping refreshes do not install a stale watch', () async {
    final cubit = build();
    await cubit.refresh();
    repository.cancellation = Completer<void>();
    final pending = cubit.refresh();
    await cubit.refresh();
    repository.cancellation!.complete();
    await pending;
    expect(repository.controllers, hasLength(2));
    expect(repository.cancellations, 1);
    await cubit.close();
  });

  test('close during cancellation prevents a late watch or timer', () async {
    final timers = _Timers();
    await timers.run(() async {
      final cubit = build();
      await cubit.refresh();
      repository.cancellation = Completer<void>();
      final pending = cubit.refresh();
      await cubit.close();
      repository.cancellation!.complete();
      await pending;
      dateService.current = DateTime(2026, 11, 20);
      expect(timers.values.every((timer) => !timer.isActive), isTrue);
      timers.values.last.fire();
      expect(repository.controllers, hasLength(1));
      expect(repository.cancellations, 1);
    });
  });
}
