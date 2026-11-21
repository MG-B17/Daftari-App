import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_colors.dart';

/// All design-space sizing lives here, not in feature widgets.
abstract final class AppSpacing {
  static double get pinMaxWidth => 360.w.clamp(280, 400).toDouble();
  static double get pinKeySize => 64.r.clamp(48, 80).toDouble();
  static double get pinDotSize => 16.r;
  static double get pinDotGap => 20.r;
  static double get pinLogoSize => 72.r;
  static double get pinBookSize => 36.r;
  static double get pinBadgeSize => 26.r;
  static double get pinBadgeIconSize => 16.r;
  static double get pinSectionGap => 72.h;
  static double get pinTopInset => 40.h;
  static const exportWidth = 420.0;
  static const exportPadding = 24.0;
  static const exportGap = 12.0;
  static const exportSmallGap = 6.0;
  static const exportFont = 14.0;
  static const exportTitleFont = 22.0;
  static const exportAmountFont = 28.0;
  static const exportRadius = 16.0;
  static double get statementMaxWidth => 520.w.clamp(0, 520).toDouble();
  static double get statementBrandBar => 6.r;
  static double get statementActionHeight => 56.r;
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

  static double get hairline => 1;
  static double get selectedStroke => 2;
  static double get settingsSectionGap => roomy;
  static double get settingsIconBox => 40.r;
  static double get settingsBadgeSize => 40.r;
  static double get settingsOptionHeight => 72.r;
  static double get settingsRadioSize => 22.r;
  static double get settingsSheetHandleWidth => 44.w;
  static double get settingsSheetHandleHeight => 4.r;
  static EdgeInsets get settingsCardPadding => EdgeInsets.all(compact);
  static EdgeInsetsDirectional get settingsOptionPadding =>
      EdgeInsetsDirectional.symmetric(horizontal: compact, vertical: compact);
  static EdgeInsetsDirectional get settingsSectionTitlePadding =>
      EdgeInsetsDirectional.only(start: xs, bottom: sm);
  static EdgeInsetsDirectional get settingsSheetPadding =>
      EdgeInsetsDirectional.fromSTEB(lg, compact, lg, xl);
  static BorderRadius get settingsOptionRadius =>
      BorderRadius.circular(compact);
  static BorderRadius get settingsSheetRadius =>
      BorderRadius.vertical(top: Radius.circular(largeRadius));
  static double get authMaxWidth => 520.w.clamp(0, 520).toDouble();
  static double get authHeroSize => 96.r;
  static double get authHeroIcon => 44.r;
  static double get authBadgeIcon => 16.r;
  static double get authNoteIcon => 22.r;
  static EdgeInsets get authCardPadding => EdgeInsets.all(md);
  static EdgeInsets get authNotePadding => EdgeInsets.all(compact);
  static double get customersMaxWidth => 520.w.clamp(0, 520).toDouble();
  static double get customersAvatarRadius => 24.r;
  static double get customersIllustrationSize => 144.r;
  static double get customersListBottomInset => 80.r;
  static double get customersIllustrationRadius =>
      customersIllustrationSize / 2;
  static EdgeInsets get customersCardPadding => EdgeInsets.all(compact);
  static double get navigationMaxWidth => 480.r;
  static EdgeInsets get navigationMargin => EdgeInsets.fromLTRB(md, sm, md, sm);
  static EdgeInsets get navigationItemPadding =>
      EdgeInsets.symmetric(horizontal: compact, vertical: sm);
  static double get navigationIndicatorWidth => 72.r;
  static double get navigationIndicatorStretch => 24.r;
  static double get navigationElevation => 4;

  static double get dashboardMaxWidth => 520.w.clamp(0, 520).toDouble();
  static double get dashboardAvatarRadius => 22.r;
  static double get dashboardActivityIconBox => 40.r;
  static double get dashboardTipIconBox => 44.r;
  static double get dashboardActionHeight => 56.r;
  static double get dashboardSectionBarWidth => 4.w;
  static double get dashboardSectionBarHeight => 20.h;
  static double get dashboardChipRadius => 10.r;
  static EdgeInsets get dashboardCardPadding => EdgeInsets.all(cardInset);
  static EdgeInsets get dashboardSectionHeaderPadding =>
      EdgeInsets.only(bottom: sm);
  static EdgeInsets get dashboardDividerPadding =>
      EdgeInsets.symmetric(horizontal: cardInset);
}
