import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/pin_flow_mode.dart';
import '../cubit/app_lock_cubit.dart';
import '../cubit/app_lock_state.dart';
import '../cubit/pin_flow_cubit.dart';
import 'pin_header.dart';
import 'pin_keypad.dart';
import 'pin_status_section.dart';
import 'pin_unlock_actions.dart';

/// Scrollable PIN content: headings, status, keypad and unlock alternatives.
class PinLockBody extends StatelessWidget {
  const PinLockBody({super.key, required this.mode});

  final PinFlowMode mode;

  @override
  Widget build(BuildContext context) => BlocBuilder<AppLockCubit, AppLockState>(
    builder: (context, security) => BlocBuilder<PinFlowCubit, PinFlowState>(
      builder: (context, state) {
        final l10n = context.l10n;
        final flow = context.read<PinFlowCubit>();
        final title = switch (state.step) {
          PinStep.confirm => l10n.securityConfirmTitle,
          PinStep.create =>
            mode == PinFlowMode.unlock
                ? l10n.securityResetTitle
                : l10n.securitySetupTitle,
          PinStep.complete => l10n.securityComplete,
          PinStep.verify => switch (mode) {
            PinFlowMode.change => l10n.securityChangeTitle,
            PinFlowMode.disable => l10n.securityDisableTitle,
            _ => l10n.securityUnlockTitle,
          },
        };
        final subtitle = switch (state.step) {
          PinStep.confirm => l10n.securityConfirmSubtitle,
          PinStep.create => l10n.securitySetupSubtitle,
          PinStep.complete => l10n.securityCompleteDescription,
          PinStep.verify =>
            mode == PinFlowMode.unlock
                ? l10n.securityUnlockSubtitle
                : l10n.securityCurrentPin,
        };
        final message = security.message == SecurityMessage.storage
            ? l10n.securityStorageError
            : state.mismatch
            ? l10n.securityPinError
            : switch (security.message) {
                SecurityMessage.incorrect => l10n.securityPinError,
                SecurityMessage.unavailable => l10n.securityAuthUnavailable,
                _ => null,
              };
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: AppSpacing.pinMaxWidth),
              child: SingleChildScrollView(
                padding: AppSpacing.pagePadding,
                child: Column(
                  children: [
                    SizedBox(
                      height: mode == PinFlowMode.unlock
                          ? AppSpacing.pinTopInset
                          : AppSpacing.lg,
                    ),
                    PinHeader(title: title, subtitle: subtitle),
                    SizedBox(height: AppSpacing.xl),
                    PinStatusSection(
                      count: state.count,
                      busy: security.busy,
                      cooldownSeconds: security.cooldownSeconds,
                      message: message,
                    ),
                    SizedBox(height: AppSpacing.pinSectionGap),
                    PinKeypad(
                      enabled: flow.enabled,
                      onDigit: flow.enter,
                      onDelete: flow.erase,
                      onClear: flow.clear,
                    ),
                    if (mode == PinFlowMode.unlock &&
                        state.step == PinStep.verify) ...[
                      SizedBox(height: AppSpacing.md),
                      PinUnlockActions(flow: flow, security: security),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
