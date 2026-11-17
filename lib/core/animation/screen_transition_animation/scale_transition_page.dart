import 'package:flutter/material.dart';
import 'package:daftariapp/core/animation/screen_transition_animation/app_page_transition.dart';

class ScaleTransitionPage<T> extends AppPageTransition<T> {
  ScaleTransitionPage({required super.child, super.key, super.duration})
    : super(transition: _transition);

  static Widget _transition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) => ScaleTransition(
    scale: Tween<double>(begin: .95, end: 1).animate(animation),
    child: child,
  );
}
