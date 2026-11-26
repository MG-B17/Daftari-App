import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../data/services/statement_share_service.dart';
import '../../domain/entities/customer_statement_entity.dart';
import '../../domain/entities/share_statement_result.dart';
import '../../domain/entities/statement_date_range.dart';
import '../../domain/usecases/get_customer_statement_usecase.dart';
import '../services/statement_image_renderer.dart';

enum StatementShareStatus { idle, generating, handingOff, completed, failed }

enum StatementShareFailureStage { generation, handoff }

class StatementState extends Equatable {
  const StatementState({
    this.loading = true,
    this.range = StatementDateRange.all,
    this.statement,
    this.failure,
    this.shareStatus = StatementShareStatus.idle,
    this.shareSubmissionId = 0,
    this.shareFailure,
    this.shareFailureStage,
    this.shareResult,
  });

  final bool loading;
  final StatementDateRange range;
  final CustomerStatementEntity? statement;
  final AppFailure? failure;
  final StatementShareStatus shareStatus;
  final int shareSubmissionId;
  final AppFailure? shareFailure;
  final StatementShareFailureStage? shareFailureStage;
  final ShareStatementResult? shareResult;

  bool get sharing =>
      shareStatus == StatementShareStatus.generating ||
      shareStatus == StatementShareStatus.handingOff;
  bool get generating => shareStatus == StatementShareStatus.generating;
  bool get handingOff => shareStatus == StatementShareStatus.handingOff;
  bool get notFound => !loading && failure == null && statement == null;
  bool get canShare =>
      !loading && failure == null && statement != null && !sharing;

  @override
  bool get stringify => false;

  @override
  List<Object?> get props => [
    loading,
    range,
    statement,
    failure,
    shareStatus,
    shareSubmissionId,
    shareFailure,
    shareFailureStage,
    shareResult,
  ];
}

class StatementCubit extends Cubit<StatementState> {
  StatementCubit(this._getStatement, this._shareService, this._imageRenderer)
    : super(const StatementState());

  final GetCustomerStatementUseCase _getStatement;
  final StatementShareService _shareService;
  final StatementImageRenderer _imageRenderer;
  String? _customerId;
  int _generation = 0;
  int _shareSubmissionId = 0;
  bool _sharing = false;
  StatementShareStatus _activeShareStatus = StatementShareStatus.idle;

  Future<void> load(String customerId, {StatementDateRange? range}) async {
    if (isClosed) return;
    final generation = ++_generation;
    _customerId = customerId;
    final selectedRange = range ?? state.range;
    // Never leave an old customer's or old range's snapshot shareable.
    emit(
      StatementState(
        range: selectedRange,
        shareStatus: _activeShareStatus,
        shareSubmissionId: _shareSubmissionId,
      ),
    );
    Either<AppFailure, CustomerStatementEntity?> result;
    try {
      result = await _getStatement(customerId, range: selectedRange);
    } catch (_) {
      result = const Left(AppFailure(AppErrorCode.unexpected));
    }
    if (isClosed || generation != _generation) return;
    result.fold(
      (failure) => emit(
        StatementState(
          loading: false,
          range: selectedRange,
          failure: failure,
          shareStatus: _activeShareStatus,
          shareSubmissionId: _shareSubmissionId,
        ),
      ),
      (statement) => emit(
        StatementState(
          loading: false,
          range: selectedRange,
          statement: statement,
          shareStatus: _activeShareStatus,
          shareSubmissionId: _shareSubmissionId,
        ),
      ),
    );
  }

  Future<void> setRange(StatementDateRange range) async {
    if (isClosed || range == state.range) return;
    final id = _customerId;
    if (id == null) {
      emit(
        StatementState(
          range: range,
          shareStatus: _activeShareStatus,
          shareSubmissionId: _shareSubmissionId,
        ),
      );
      return;
    }
    await load(id, range: range);
  }

  Future<void> shareViaWhatsApp({
    String locale = 'ar',
    Rect? sharePositionOrigin,
  }) => _share(locale: locale, sharePositionOrigin: sharePositionOrigin);

  Future<void> shareViaSystem({
    String locale = 'ar',
    Rect? sharePositionOrigin,
  }) => _share(locale: locale, sharePositionOrigin: sharePositionOrigin);

  Future<void> _share({
    required String locale,
    Rect? sharePositionOrigin,
  }) async {
    if (isClosed || _sharing || !state.canShare) return;
    final statement = state.statement!;
    final generation = _generation;
    var prepared = false;
    _sharing = true;
    _activeShareStatus = StatementShareStatus.generating;
    _emitShare(status: StatementShareStatus.generating);
    Either<AppFailure, ShareStatementResult> result;
    try {
      result = await _shareService.shareImages(
        pages: _imageRenderer.render(statement, locale: locale),
        sharePositionOrigin: sharePositionOrigin,
        onPrepared: () {
          prepared = true;
          if (isClosed || !_sharing) return;
          _activeShareStatus = StatementShareStatus.handingOff;
          if (generation == _generation) {
            _emitShare(status: StatementShareStatus.handingOff);
          }
        },
      );
    } catch (_) {
      // Do not forward private formatter/plugin errors to observers or logs.
      result = const Left(AppFailure(AppErrorCode.unexpected));
    }
    _sharing = false;
    _activeShareStatus = StatementShareStatus.idle;
    if (isClosed) return;
    if (generation != _generation) {
      _emitShare(status: StatementShareStatus.idle);
      return;
    }
    _shareSubmissionId++;
    result.fold(
      (failure) => _emitShare(
        status: StatementShareStatus.failed,
        failure: failure,
        failureStage: prepared
            ? StatementShareFailureStage.handoff
            : StatementShareFailureStage.generation,
      ),
      (shareResult) => _emitShare(
        status: StatementShareStatus.completed,
        result: shareResult,
      ),
    );
  }

  void _emitShare({
    required StatementShareStatus status,
    AppFailure? failure,
    StatementShareFailureStage? failureStage,
    ShareStatementResult? result,
  }) {
    emit(
      StatementState(
        loading: state.loading,
        range: state.range,
        statement: state.statement,
        failure: state.failure,
        shareStatus: status,
        shareSubmissionId: _shareSubmissionId,
        shareFailure: failure,
        shareFailureStage: failureStage,
        shareResult: result,
      ),
    );
  }

  @override
  Future<void> close() {
    _generation++;
    return super.close();
  }
}
