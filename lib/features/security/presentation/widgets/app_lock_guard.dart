import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../cubit/app_lock_cubit.dart';
import '../cubit/app_lock_state.dart';
import '../screens/pin_lock_screen.dart';

class AppLockGuard extends StatefulWidget {
  const AppLockGuard({super.key, required this.lock, required this.child});
  final AppLockCubit lock;
  final Widget child;

  @override
  State<AppLockGuard> createState() => _AppLockGuardState();
}

class _AppLockGuardState extends State<AppLockGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      widget.lock.lifecycle(lifecycle);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      widget.lock.lifecycle(state);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AppLockCubit, AppLockState>(
    bloc: widget.lock,
    builder: (context, state) => Stack(
      fit: StackFit.expand,
      children: [
        // Hide all routes (including dialogs and outgoing transitions) while
        // inactive. The router independently removes protected routes on lock.
        Offstage(
          offstage: state.locked,
          child: ExcludeSemantics(
            excluding: state.obscured || state.locked,
            child: IgnorePointer(
              ignoring: state.obscured || state.locked,
              child: widget.child,
            ),
          ),
        ),
        if (state.locked)
          Navigator(
            pages: const [MaterialPage<void>(child: PinLockScreen())],
            onDidRemovePage: (_) {},
          ),
        if (state.obscured)
          Positioned.fill(
            child: ColoredBox(color: context.theme.scaffoldBackgroundColor),
          ),
      ],
    ),
  );
}
