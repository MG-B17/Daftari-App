import 'package:flutter/material.dart';
import 'package:daftariapp/core/animation/screen_transition_animation/app_page_transition.dart';

class BottomSheetTransitionPage<T> extends AppPageTransition<T> {
  BottomSheetTransitionPage({required super.child, super.key, super.duration})
    : super(transition: _transition);

  static Widget _transition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(animation),
    child: child,
  );
}
