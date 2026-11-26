import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StaggeredListItem extends StatelessWidget {
  const StaggeredListItem({required this.index, required this.child, super.key})
    : assert(index >= 0);

  static const staggerStep = Duration(milliseconds: 65);
  static const duration = Duration(milliseconds: 320);
  static const maxAnimatedIndex = 6;
  static const slideBegin = 0.08;

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) ||
        index == 0 ||
        index > maxAnimatedIndex) {
      return child;
    }

    final delay = staggerStep * index;
    return child
        .animate(delay: delay)
        .fadeIn(duration: duration, curve: Curves.easeOutCubic)
        .slideY(
          begin: slideBegin,
          end: 0,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
  }
}
