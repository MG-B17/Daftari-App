import 'package:flutter/material.dart';

import '../../extensions/context_extensions.dart';

abstract final class AppGradients {
  static LinearGradient onboardingCard(BuildContext context) {
    final colors = context.appColors;
    return LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        colors.onboardingGradientStart,
        colors.onboardingGradientMiddle,
        colors.onboardingGradientEnd,
      ],
    );
  }
}
