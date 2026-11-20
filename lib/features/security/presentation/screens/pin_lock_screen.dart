import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../domain/entities/pin_flow_mode.dart';
import '../cubit/app_lock_cubit.dart';
import '../cubit/app_lock_state.dart';
import '../cubit/pin_flow_cubit.dart';
import '../widgets/pin_lock_body.dart';

class PinLockScreen extends StatelessWidget {
  const PinLockScreen({super.key, this.mode = PinFlowMode.unlock});
  final PinFlowMode mode;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PinFlowCubit(context.read<AppLockCubit>(), mode),
    child: _PinLockView(mode: mode),
  );
}

class _PinLockView extends StatelessWidget {
  const _PinLockView({required this.mode});
  final PinFlowMode mode;

  @override
  Widget build(BuildContext context) =>
      BlocListener<AppLockCubit, AppLockState>(
        listenWhen: (previous, next) =>
            previous.inputRevision != next.inputRevision,
        listener: (context, _) => context.read<PinFlowCubit>().resetInput(),
        child: BlocListener<PinFlowCubit, PinFlowState>(
          listenWhen: (previous, next) =>
              previous.step != PinStep.complete &&
              next.step == PinStep.complete,
          listener: (context, _) {
            if (mode == PinFlowMode.unlock) {
              return; // Redirect owns unlock navigation.
            }
            if (context.canPop()) {
              context.pop(true);
            } else {
              context.go(AppRoutes.settings);
            }
          },
          child: BlocSelector<AppLockCubit, AppLockState, bool>(
            selector: (state) => state.busy,
            builder: (context, busy) => PopScope(
              canPop: mode != PinFlowMode.unlock && !busy,
              child: Scaffold(
                backgroundColor: context.appColors.paperBackground,
                appBar: mode == PinFlowMode.unlock
                    ? null
                    : AppBar(
                        title: Text(context.l10n.appTitle),
                        automaticallyImplyLeading: !busy,
                      ),
                body: PinLockBody(mode: mode),
              ),
            ),
          ),
        ),
      );
}
