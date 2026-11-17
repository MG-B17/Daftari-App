import 'package:flutter/material.dart';
import 'package:daftariapp/core/animation/screen_transition_animation/app_page_transition.dart';

class SlideRightTransitionPage<T> extends AppPageTransition<T> {
  SlideRightTransitionPage({required super.child, super.key, super.duration})
    : super(transition: _transition);

  static Widget _transition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) => SlideTransition(
    textDirection: Directionality.of(context),
    position: Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(animation),
    child: child,
  );
}
