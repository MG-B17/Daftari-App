import 'package:flutter/material.dart';
import 'package:daftariapp/core/animation/screen_transition_animation/app_page_transition.dart';

class FadeTransitionPage<T> extends AppPageTransition<T> {
  FadeTransitionPage({required super.child, super.key, super.duration})
    : super(transition: _transition);

  static Widget _transition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}
