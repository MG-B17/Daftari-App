import 'package:equatable/equatable.dart';

import 'app_exception.dart';

/// Safe value for Either and presentation state; never stores a raw cause.
final class AppFailure extends Equatable {
  const AppFailure(this.errorCode);

  factory AppFailure.fromException(AppException exception) =>
      AppFailure(exception.errorCode);

  final AppErrorCode errorCode;
  String get code => errorCode.code;
  String get message => errorCode.message;

  @override
  List<Object> get props => [errorCode];
}
