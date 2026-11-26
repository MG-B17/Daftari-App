import 'package:equatable/equatable.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../customers/domain/entities/customer_entity.dart';
import '../../domain/usecases/customer_search_matcher.dart';

class SearchState extends Equatable {
  const SearchState({
    this.loading = true,
    this.customers = const [],
    this.query = '',
    this.failure,
  });

  final bool loading;
  final List<CustomerEntity> customers;
  final String query;
  final AppFailure? failure;

  bool get hasQuery => query.trim().isNotEmpty;

  List<CustomerEntity> get results =>
      CustomerSearchMatcher.filter(customers, query);

  SearchState copyWith({
    bool? loading,
    List<CustomerEntity>? customers,
    String? query,
    AppFailure? failure,
    bool clearFailure = false,
  }) => SearchState(
    loading: loading ?? this.loading,
    customers: customers ?? this.customers,
    query: query ?? this.query,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [loading, customers, query, failure];
}
