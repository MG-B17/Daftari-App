import 'package:flutter/material.dart';

import '../../../../core/theme/spacing/app_spacing.dart';

class LiquidNavItem {
  const LiquidNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class LiquidNavigationBar extends StatelessWidget {
  const LiquidNavigationBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.backgroundColor,
    this.indicatorColor,
    this.selectedColor,
    this.unselectedColor,
    super.key,
  }) : assert(items.length > 0),
       assert(selectedIndex >= 0 && selectedIndex < items.length);

  final List<LiquidNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final Color? selectedColor;
  final Color? unselectedColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 400);
    return SafeArea(
      top: false,
      child: Padding(
        padding: AppSpacing.navigationMargin,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppSpacing.navigationMaxWidth,
            ),
            child: Material(
              color: backgroundColor ?? colors.surface,
              elevation: AppSpacing.navigationElevation,
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xs),
                child: SizedBox(
                  height: AppSpacing.controlHeight,
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        alignment: AlignmentDirectional.lerp(
                          AlignmentDirectional.centerStart,
                          AlignmentDirectional.centerEnd,
                          items.length == 1
                              ? 0
                              : selectedIndex / (items.length - 1),
                        )!,
                        duration: duration,
                        curve: Curves.easeOutBack,
                        child: FractionallySizedBox(
                          widthFactor: 1 / items.length,
                          heightFactor: 1,
                          child: DecoratedBox(
                            key: const ValueKey('navigation-indicator'),
                            decoration: BoxDecoration(
                              color:
                                  indicatorColor ?? colors.secondaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.pillRadius,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < items.length; i++)
                            Expanded(
                              child: Semantics(
                                label: items[i].label,
                                selected: selectedIndex == i,
                                button: true,
                                child: InkWell(
                                  key: ValueKey('navigation-$i'),
                                  onTap: () => onSelected(i),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.pillRadius,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      selectedIndex == i
                                          ? items[i].selectedIcon
                                          : items[i].icon,
                                      size: AppSpacing.icon,
                                      color: selectedIndex == i
                                          ? selectedColor ?? colors.primary
                                          : unselectedColor ?? colors.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
