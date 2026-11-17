import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppPageTransition<T> extends CustomTransitionPage<T> {
  AppPageTransition({
    required super.child,
    required Widget Function(BuildContext, Animation<double>, Widget)
    transition,
    super.key,
    super.name,
    super.arguments,
    Duration duration = const Duration(milliseconds: 300),
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           if (MediaQuery.disableAnimationsOf(context)) return child;
           return transition(
             context,
             CurvedAnimation(parent: animation, curve: Curves.easeOut),
             child,
           );
         },
       );
}
