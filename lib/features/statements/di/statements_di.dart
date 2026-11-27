import 'package:get_it/get_it.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/services/date/date_service.dart';
import '../../../core/services/image_exporter/widget_image_exporter.dart';
import '../data/repositories/statement_repository_impl.dart';
import '../data/services/statement_share_service.dart';
import '../domain/repositories/statement_repository.dart';
import '../domain/usecases/get_customer_statement_usecase.dart';
import '../presentation/cubit/statement_cubit.dart';
import '../presentation/services/statement_image_renderer.dart';

void registerStatementsDependencies(GetIt sl) {
  if (!sl.isRegistered<StatementRepository>()) {
    sl.registerLazySingleton<StatementRepository>(
      () => StatementRepositoryImpl(
        sl<CustomerDao>(),
        sl<TransactionDao>(),
        sl<DateService>(),
        sl<ErrorHandler>(),
      ),
    );
  }
  if (!sl.isRegistered<GetCustomerStatementUseCase>()) {
    sl.registerLazySingleton<GetCustomerStatementUseCase>(
      () => GetCustomerStatementUseCase(sl<StatementRepository>()),
    );
  }
  if (!sl.isRegistered<StatementImageRenderer>()) {
    sl.registerLazySingleton<StatementImageRenderer>(
      () => WidgetStatementImageRenderer(sl<WidgetImageExporter>()),
    );
  }
  if (!sl.isRegistered<StatementShareService>()) {
    sl.registerLazySingleton<StatementShareService>(
      () => StatementShareService(sl<ErrorHandler>()),
    );
  }
  if (!sl.isRegistered<StatementCubit>()) {
    sl.registerFactory<StatementCubit>(
      () => StatementCubit(
        sl<GetCustomerStatementUseCase>(),
        sl<StatementShareService>(),
        sl<StatementImageRenderer>(),
      ),
    );
  }
}
