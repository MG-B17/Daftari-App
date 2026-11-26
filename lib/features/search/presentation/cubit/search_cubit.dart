import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../domain/usecases/watch_search_customers_usecase.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._watchCustomers) : super(const SearchState());

  final WatchSearchCustomersUseCase _watchCustomers;
  StreamSubscription<Either<AppFailure, List<CustomerEntity>>>? _subscription;
  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    final previous = _subscription;
    _subscription = null;
    emit(state.copyWith(loading: true, clearFailure: true));
    if (previous != null) {
      unawaited(previous.cancel());
    }
    if (isClosed || generation != _generation) return;
    _subscription = _watchCustomers().listen(
      (result) {
        if (isClosed || generation != _generation) return;
        result.fold(
          (failure) => emit(state.copyWith(loading: false, failure: failure)),
          (customers) => emit(
            state.copyWith(
              loading: false,
              customers: customers,
              clearFailure: true,
            ),
          ),
        );
      },
      onError: (Object error) {
        if (!isClosed && generation == _generation) {
          emit(
            state.copyWith(
              loading: false,
              failure: const AppFailure(AppErrorCode.unexpected),
            ),
          );
        }
      },
    );
  }

  void setQuery(String query) {
    if (isClosed) return;
    emit(state.copyWith(query: query));
  }

  void clearQuery() => setQuery('');

  @override
  Future<void> close() async {
    _generation++;
    await _subscription?.cancel();
    return super.close();
  }
}
