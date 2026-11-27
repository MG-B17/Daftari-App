import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/date/date_service.dart';
import '../../domain/entities/dashboard_summary_entity.dart';
import '../../domain/usecases/watch_dashboard_summary_usecase.dart';

class DashboardState extends Equatable {
  const DashboardState({this.loading = true, this.summary, this.failure});

  final bool loading;
  final DashboardSummaryEntity? summary;
  final AppFailure? failure;

  @override
  List<Object?> get props => [loading, summary, failure];
}

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._watch, this._dateService)
    : super(const DashboardState());

  final WatchDashboardSummaryUseCase _watch;
  final DateService _dateService;
  StreamSubscription<Either<AppFailure, DashboardSummaryEntity>>? _subscription;
  Timer? _midnightTimer;
  DateTime? _subscriptionDay;
  int _generation = 0;
  bool _closing = false;

  Future<void> refresh() async {
    if (_closing || isClosed) return;
    final generation = ++_generation;
    final now = _dateService.now();
    _subscriptionDay = _day(now);
    _scheduleMidnight(now);
    final previous = _subscription;
    _subscription = null;
    await previous?.cancel();
    if (_closing || isClosed || generation != _generation) return;
    emit(DashboardState(summary: state.summary));
    try {
      _subscription = _watch().listen((result) {
        if (_closing || isClosed || generation != _generation) return;
        result.fold(
          (failure) => emit(
            DashboardState(
              loading: false,
              summary: state.summary,
              failure: failure,
            ),
          ),
          (summary) => emit(DashboardState(loading: false, summary: summary)),
        );
      }, onError: (Object _) => _emitUnexpectedFailure(generation));
    } catch (_) {
      _emitUnexpectedFailure(generation);
    }
  }

  Future<void> refreshIfDayChanged() async {
    if (_closing || isClosed) return;
    if (_subscriptionDay != _day(_dateService.now())) {
      await refresh();
    }
  }

  void _emitUnexpectedFailure(int generation) {
    if (_closing || isClosed || generation != _generation) return;
    emit(
      DashboardState(
        loading: false,
        summary: state.summary,
        failure: const AppFailure(AppErrorCode.unexpected),
      ),
    );
  }

  void _scheduleMidnight(DateTime now) {
    _midnightTimer?.cancel();
    // Calendar arithmetic respects local DST days rather than assuming 24 hours.
    final nextMidnight = now.isUtc
        ? DateTime.utc(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (_closing || isClosed) return;
      final current = _dateService.now();
      if (_subscriptionDay == _day(current)) {
        // The wall clock may have moved backwards since the timer was created.
        _scheduleMidnight(current);
      } else {
        unawaited(refresh());
      }
    });
  }

  static DateTime _day(DateTime value) => value.isUtc
      ? DateTime.utc(value.year, value.month, value.day)
      : DateTime(value.year, value.month, value.day);

  @override
  Future<void> close() async {
    _closing = true;
    _generation++;
    _midnightTimer?.cancel();
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    return super.close();
  }
}
