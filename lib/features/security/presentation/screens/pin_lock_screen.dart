import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_success_dialog.dart';
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

class _PinLockView extends StatefulWidget {
  const _PinLockView({required this.mode});
  final PinFlowMode mode;

  @override
  State<_PinLockView> createState() => _PinLockViewState();
}

class _PinLockViewState extends State<_PinLockView> {
  bool _presentingDialog = false;

  Future<void> _handleOutcome(BuildContext context, PinFlowState state) async {
    if (!mounted || _presentingDialog || widget.mode == PinFlowMode.unlock) {
      return;
    }
    final lockCubit = context.read<AppLockCubit>();
    if (lockCubit.state.locked) return;
    final flowCubit = context.read<PinFlowCubit>();
    if (!flowCubit.consumeOutcome(state.outcomeId)) return;

    final l10n = context.l10n;
    _presentingDialog = true;
    try {
      switch (state.outcome) {
        case PinFlowOutcome.setupSuccess:
          await AppSuccessDialog.show(
            context,
            title: l10n.securityPinSetupSuccessTitle,
            message: l10n.securityPinSetupSuccessMessage,
          );
        case PinFlowOutcome.changeSuccess:
          await AppSuccessDialog.show(
            context,
            title: l10n.securityComplete,
            message: l10n.securityPinChangedMessage,
          );
        case PinFlowOutcome.disableSuccess:
          await AppSuccessDialog.show(
            context,
            title: l10n.securityPinDisabledTitle,
            message: l10n.securityPinDisabledMessage,
          );
        case PinFlowOutcome.failed:
          final errorMessage = switch (lockCubit.state.message) {
            SecurityMessage.unavailable => l10n.securityAuthUnavailable,
            SecurityMessage.incorrect => l10n.securityPinError,
            _ => l10n.errorMessage,
          };
          await AppErrorDialog.show(context, message: errorMessage);
        case PinFlowOutcome.none:
          return;
      }
    } finally {
      _presentingDialog = false;
    }

    if (!mounted || lockCubit.state.locked) return;
    if (state.outcome == PinFlowOutcome.failed) return;

    if (this.context.canPop()) {
      this.context.pop(true);
    } else {
      this.context.go(AppRoutes.settings);
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<AppLockCubit, AppLockState>(
        listenWhen: (previous, next) =>
            previous.inputRevision != next.inputRevision,
        listener: (context, _) => context.read<PinFlowCubit>().resetInput(),
        child: BlocListener<PinFlowCubit, PinFlowState>(
          listenWhen: (previous, next) =>
              previous.outcomeId != next.outcomeId &&
              next.outcome != PinFlowOutcome.none,
          listener: (context, state) =>
              unawaited(_handleOutcome(context, state)),
          child: BlocSelector<AppLockCubit, AppLockState, bool>(
            selector: (state) => state.busy,
            builder: (context, busy) => PopScope(
              canPop: widget.mode != PinFlowMode.unlock && !busy,
              child: Scaffold(
                backgroundColor: context.appColors.paperBackground,
                appBar: widget.mode == PinFlowMode.unlock
                    ? null
                    : AppBar(
                        title: Text(context.l10n.appTitle),
                        automaticallyImplyLeading: !busy,
                      ),
                body: PinLockBody(mode: widget.mode),
              ),
            ),
          ),
        ),
      );
}
