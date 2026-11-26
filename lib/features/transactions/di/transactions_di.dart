import 'package:get_it/get_it.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/error_handler.dart';
import '../../customers/domain/usecases/watch_customers_usecase.dart';
import '../data/repositories/transaction_repository_impl.dart';
import '../domain/repositories/transaction_repository.dart';
import '../domain/usecases/create_transaction_usecase.dart';
import '../domain/usecases/edit_transaction_usecase.dart';
import '../domain/usecases/get_transaction_by_id_usecase.dart';
import '../domain/usecases/soft_delete_transaction_usecase.dart';
import '../domain/usecases/watch_customer_transactions_usecase.dart';
import '../presentation/cubit/customer_transactions_cubit.dart';
import '../presentation/cubit/transaction_form_cubit.dart';

void registerTransactionsDependencies(GetIt sl) {
  if (!sl.isRegistered<TransactionRepository>()) {
    sl.registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(sl<TransactionDao>(), sl<ErrorHandler>()),
    );
  }
  if (!sl.isRegistered<WatchCustomerTransactionsUseCase>()) {
    sl.registerLazySingleton<WatchCustomerTransactionsUseCase>(
      () => WatchCustomerTransactionsUseCase(sl<TransactionRepository>()),
    );
  }
  if (!sl.isRegistered<GetTransactionByIdUseCase>()) {
    sl.registerLazySingleton<GetTransactionByIdUseCase>(
      () => GetTransactionByIdUseCase(sl<TransactionRepository>()),
    );
  }
  if (!sl.isRegistered<CreateTransactionUseCase>()) {
    sl.registerLazySingleton<CreateTransactionUseCase>(
      () => CreateTransactionUseCase(sl<TransactionRepository>()),
    );
  }
  if (!sl.isRegistered<EditTransactionUseCase>()) {
    sl.registerLazySingleton<EditTransactionUseCase>(
      () => EditTransactionUseCase(sl<TransactionRepository>()),
    );
  }
  if (!sl.isRegistered<SoftDeleteTransactionUseCase>()) {
    sl.registerLazySingleton<SoftDeleteTransactionUseCase>(
      () => SoftDeleteTransactionUseCase(sl<TransactionRepository>()),
    );
  }
  if (!sl.isRegistered<CustomerTransactionsCubit>()) {
    sl.registerFactory<CustomerTransactionsCubit>(
      () => CustomerTransactionsCubit(
        sl<WatchCustomerTransactionsUseCase>(),
        sl<SoftDeleteTransactionUseCase>(),
      ),
    );
  }
  if (!sl.isRegistered<TransactionFormCubit>()) {
    sl.registerFactory<TransactionFormCubit>(
      () => TransactionFormCubit(
        sl<WatchCustomersUseCase>(),
        sl<GetTransactionByIdUseCase>(),
        sl<CreateTransactionUseCase>(),
        sl<EditTransactionUseCase>(),
      ),
    );
  }
}
