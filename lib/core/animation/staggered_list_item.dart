import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StaggeredListItem extends StatelessWidget {
  const StaggeredListItem({required this.index, required this.child, super.key})
    : assert(index >= 0);

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final delay = Duration(milliseconds: index.clamp(0, 6) * 50);
    return child
        .animate(delay: delay)
        .fadeIn(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        )
        .slideY(begin: 0.05, end: 0);
  }
}
