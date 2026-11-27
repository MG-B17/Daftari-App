import 'package:get_it/get_it.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/services/contact_picker/contact_picker_service.dart';
import '../data/repositories/customer_repository_impl.dart';
import '../domain/repositories/customer_repository.dart';
import '../domain/usecases/create_customer_usecase.dart';
import '../domain/usecases/pick_contact_usecase.dart';
import '../domain/usecases/soft_delete_customer_usecase.dart';
import '../domain/usecases/update_customer_usecase.dart';
import '../domain/usecases/watch_customer_details_usecase.dart';
import '../domain/usecases/watch_customers_usecase.dart';
import '../presentation/cubit/customer_details_cubit.dart';
import '../presentation/cubit/customer_form_cubit.dart';
import '../presentation/cubit/customers_list_cubit.dart';

void registerCustomersDependencies(GetIt sl) {
  if (!sl.isRegistered<CustomerRepository>()) {
    sl.registerLazySingleton<CustomerRepository>(
      () => CustomerRepositoryImpl(
        sl<CustomerDao>(),
        sl<ContactPickerService>(),
        sl<ErrorHandler>(),
      ),
    );
  }
  if (!sl.isRegistered<WatchCustomersUseCase>()) {
    sl.registerLazySingleton<WatchCustomersUseCase>(
      () => WatchCustomersUseCase(sl<CustomerRepository>()),
    );
  }
  if (!sl.isRegistered<WatchCustomerDetailsUseCase>()) {
    sl.registerLazySingleton<WatchCustomerDetailsUseCase>(
      () => WatchCustomerDetailsUseCase(sl<CustomerRepository>()),
    );
  }
  if (!sl.isRegistered<CreateCustomerUseCase>()) {
    sl.registerLazySingleton<CreateCustomerUseCase>(
      () => CreateCustomerUseCase(sl<CustomerRepository>()),
    );
  }
  if (!sl.isRegistered<UpdateCustomerUseCase>()) {
    sl.registerLazySingleton<UpdateCustomerUseCase>(
      () => UpdateCustomerUseCase(sl<CustomerRepository>()),
    );
  }
  if (!sl.isRegistered<SoftDeleteCustomerUseCase>()) {
    sl.registerLazySingleton<SoftDeleteCustomerUseCase>(
      () => SoftDeleteCustomerUseCase(sl<CustomerRepository>()),
    );
  }
  if (!sl.isRegistered<PickContactUseCase>()) {
    sl.registerLazySingleton<PickContactUseCase>(
      () => PickContactUseCase(sl<CustomerRepository>()),
    );
  }
  if (!sl.isRegistered<CustomersListCubit>()) {
    sl.registerFactory<CustomersListCubit>(
      () => CustomersListCubit(
        sl<WatchCustomersUseCase>(),
        sl<PickContactUseCase>(),
      ),
    );
  }
  if (!sl.isRegistered<CustomerFormCubit>()) {
    sl.registerFactory<CustomerFormCubit>(
      () => CustomerFormCubit(
        sl<CreateCustomerUseCase>(),
        sl<UpdateCustomerUseCase>(),
        sl<WatchCustomerDetailsUseCase>(),
        sl<PickContactUseCase>(),
      ),
    );
  }
  if (!sl.isRegistered<CustomerDetailsCubit>()) {
    sl.registerFactory<CustomerDetailsCubit>(
      () => CustomerDetailsCubit(
        sl<WatchCustomerDetailsUseCase>(),
        sl<SoftDeleteCustomerUseCase>(),
      ),
    );
  }
}
