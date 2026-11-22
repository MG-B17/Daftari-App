import '../../../../../core/errors/app_exception.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../core/utils/validators.dart';

abstract final class AuthValidation {
  static AppFailure? validateEmail(String email) =>
      Validators.email(email) != null
      ? const AppFailure(AppErrorCode.validation)
      : null;

  static AppFailure? validatePassword(String password) =>
      Validators.password(password) != null
      ? const AppFailure(AppErrorCode.validation)
      : null;

  static AppFailure? validateShopName(String shopName) =>
      shopName.trim().isEmpty
      ? const AppFailure(AppErrorCode.validation)
      : null;

  static AppFailure? validateSignIn({
    required String email,
    required String password,
  }) => validateEmail(email) ?? validatePassword(password);

  static AppFailure? validateSignUp({
    required String email,
    required String password,
    required String shopName,
  }) =>
      validateShopName(shopName) ??
      validateEmail(email) ??
      validatePassword(password);
}
