import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// All design-space sizing lives here, not in feature widgets.
abstract final class AppSpacing {
  static double get xs => 4.r;
  static double get sm => 8.r;
  static double get md => 16.r;
  static double get lg => 24.r;
  static double get xl => 32.r;
  static double get icon => 24.r;
  static double get stateIcon => 56.r;
  static double get controlHeight => 48.r;
  static double get radius => 12.r;
  static BorderRadius get borderRadius => BorderRadius.circular(radius);
  static EdgeInsetsDirectional get pagePadding => EdgeInsetsDirectional.all(md);
  static EdgeInsetsDirectional get controlPadding =>
      EdgeInsetsDirectional.symmetric(horizontal: md, vertical: sm);
}
