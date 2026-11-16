import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_colors.dart';

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

  static double get xxs => 2.r;
  static double get tight => 6.r;
  static double get compact => 12.r;
  static double get roomy => 20.r;
  static double get xxl => 40.r;
  static double get iconSmall => 20.r;
  static double get iconMedium => 22.r;
  static double get badgeIcon => 13.r;
  static double get cardInset => 14.r;
  static double get cardRadius => 18.r;
  static double get largeRadius => 24.r;
  static double get pillRadius => 28.r;
  static double get progressStroke => 3.r;
  static double get indicatorDot => 10.r;
  static double get indicatorActiveWidth => 28.r;

  static double get introMaxWidth => 520.w.clamp(0, 520).toDouble();
  static bool get hasCompactHeight => ScreenUtil().screenHeight < 600;
  static EdgeInsets get introPagePadding =>
      EdgeInsets.symmetric(horizontal: lg, vertical: md);
  static EdgeInsets get introAppBarPadding =>
      EdgeInsets.fromLTRB(lg, compact, lg, 0);
  static EdgeInsets get introNextButtonPadding =>
      EdgeInsets.fromLTRB(lg, hasCompactHeight ? md : 64.h, lg, xl);

  static double get onboardingCardWidth => 280.w.clamp(240, 360).toDouble();
  static double get onboardingCardHeight => 240.h.clamp(240, 320).toDouble();
  static EdgeInsets get badgePadding =>
      EdgeInsets.symmetric(horizontal: 10.r, vertical: 5.r);
  static BoxShadow get badgeShadow => BoxShadow(
    color: AppColors.shadow,
    blurRadius: xs,
    offset: Offset(0, xxs),
  );

  static double get splashLogoSize => 112.r;
  static double get splashLogoImageSize => 80.r;
  static EdgeInsets get splashProgressPadding =>
      EdgeInsets.only(bottom: xxl, top: md);
}
