import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class PinDotsIndicator extends StatelessWidget {
  const PinDotsIndicator({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.securityPinProgress(count),
    liveRegion: true,
    child: ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          4,
          (index) => Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.pinDotGap / 2),
            child: Container(
              width: AppSpacing.pinDotSize,
              height: AppSpacing.pinDotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < count
                    ? context.appColors.lockActiveDot
                    : context.appColors.lockAccentSurface,
                border: Border.all(color: context.colorScheme.primary),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
