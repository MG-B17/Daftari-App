import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../constants/app_constants.dart';

abstract final class AppTypography {
  static TextTheme get textTheme => TextTheme(
    headlineMedium: _style(28, FontWeight.w700),
    titleLarge: _style(22, FontWeight.w700),
    titleMedium: _style(16, FontWeight.w600),
    bodyLarge: _style(16, FontWeight.w400),
    bodyMedium: _style(14, FontWeight.w400),
    bodySmall: _style(12, FontWeight.w400),
    labelLarge: _style(14, FontWeight.w700),
    labelMedium: _style(12, FontWeight.w600),
  );

  static TextStyle _style(double size, FontWeight weight) => TextStyle(
    fontFamily: AppConstants.fontFamily,
    fontSize: size.sp,
    fontWeight: weight,
    height: 1.5,
  );
}
