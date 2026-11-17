import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/utils/validators.dart';

abstract final class CustomerValidation {
  static AppFailure? validate({required String name, String? phone}) {
    if (Validators.customerName(name) != null ||
        Validators.egyptianMobile(phone) != null) {
      return const AppFailure(AppErrorCode.validation);
    }
    return null;
  }
}
