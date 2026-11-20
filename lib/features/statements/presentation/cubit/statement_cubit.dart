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
import '../../domain/formatters/statement_formatter.dart';
import '../../domain/usecases/get_customer_statement_usecase.dart';

class StatementState extends Equatable {
  const StatementState({
    this.loading = true,
    this.range = StatementDateRange.all,
    this.statement,
    this.failure,
    this.sharing = false,
    this.shareFailure,
    this.shareResult,
  });

  final bool loading;
  final StatementDateRange range;
  final CustomerStatementEntity? statement;
  final AppFailure? failure;
  final bool sharing;
  final AppFailure? shareFailure;
  final ShareStatementResult? shareResult;

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
    sharing,
    shareFailure,
    shareResult,
  ];
}

class StatementCubit extends Cubit<StatementState> {
  StatementCubit(this._getStatement, this._shareService)
    : super(const StatementState());

  final GetCustomerStatementUseCase _getStatement;
  final StatementShareService _shareService;
  String? _customerId;
  int _generation = 0;
  bool _sharing = false;

  Future<void> load(String customerId, {StatementDateRange? range}) async {
    if (isClosed) return;
    final generation = ++_generation;
    _customerId = customerId;
    final selectedRange = range ?? state.range;
    // Never leave an old customer's or old range's snapshot shareable.
    emit(StatementState(range: selectedRange, sharing: _sharing));
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
          sharing: _sharing,
        ),
      ),
      (statement) => emit(
        StatementState(
          loading: false,
          range: selectedRange,
          statement: statement,
          sharing: _sharing,
        ),
      ),
    );
  }

  Future<void> setRange(StatementDateRange range) async {
    if (isClosed || range == state.range) return;
    final id = _customerId;
    if (id == null) {
      emit(StatementState(range: range));
      return;
    }
    await load(id, range: range);
  }

  Future<void> shareViaWhatsApp({
    String locale = 'ar',
    Rect? sharePositionOrigin,
  }) => _share(
    viaWhatsApp: true,
    locale: locale,
    sharePositionOrigin: sharePositionOrigin,
  );

  Future<void> shareViaSystem({
    String locale = 'ar',
    Rect? sharePositionOrigin,
  }) => _share(
    viaWhatsApp: false,
    locale: locale,
    sharePositionOrigin: sharePositionOrigin,
  );

  Future<void> _share({
    required bool viaWhatsApp,
    required String locale,
    Rect? sharePositionOrigin,
  }) async {
    if (isClosed || _sharing || !state.canShare) return;
    final statement = state.statement!;
    final generation = _generation;
    _sharing = true;
    _emitShare(sharing: true);
    Either<AppFailure, ShareStatementResult> result;
    try {
      final text = StatementFormatter.format(statement, locale: locale);
      result = viaWhatsApp
          ? await _shareService.shareViaWhatsApp(
              text: text,
              phone: statement.customer.phone,
              sharePositionOrigin: sharePositionOrigin,
            )
          : await _shareService.shareViaSystem(
              text: text,
              sharePositionOrigin: sharePositionOrigin,
            );
    } catch (_) {
      // Do not forward private formatter/plugin errors to observers or logs.
      result = const Left(AppFailure(AppErrorCode.unexpected));
    }
    _sharing = false;
    if (isClosed) return;
    if (generation != _generation) {
      _emitShare(sharing: false);
      return;
    }
    result.fold(
      (failure) => _emitShare(sharing: false, failure: failure),
      (result) => _emitShare(sharing: false, result: result),
    );
  }

  void _emitShare({
    required bool sharing,
    AppFailure? failure,
    ShareStatementResult? result,
  }) {
    emit(
      StatementState(
        loading: state.loading,
        range: state.range,
        statement: state.statement,
        failure: state.failure,
        sharing: sharing,
        shareFailure: failure,
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
