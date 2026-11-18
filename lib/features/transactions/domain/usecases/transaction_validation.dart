import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/validators.dart';

abstract final class TransactionValidation {
  static AppFailure? validate({required int amountPiasters}) =>
      Validators.positivePiasters(amountPiasters) == null
      ? null
      : const AppFailure(AppErrorCode.validation);
}
