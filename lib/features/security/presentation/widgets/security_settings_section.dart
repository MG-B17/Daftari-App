import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_success_dialog.dart';
import '../../../../core/widgets/daftari_loading.dart';
import '../../../settings/presentation/widgets/settings_section_card.dart';
import '../../../settings/presentation/widgets/settings_icon_box.dart';
import '../../domain/entities/pin_flow_mode.dart';
import '../../domain/entities/security_settings.dart';
import '../cubit/app_lock_cubit.dart';
import '../cubit/app_lock_state.dart';

class SecuritySettingsSection extends StatefulWidget {
  const SecuritySettingsSection({super.key});

  @override
  State<SecuritySettingsSection> createState() =>
      _SecuritySettingsSectionState();
}

class _SecuritySettingsSectionState extends State<SecuritySettingsSection> {
  bool _presentingDialog = false;

  void _openPin(BuildContext context, PinFlowMode mode) =>
      context.push<bool>('${AppRoutes.settingsPin}?mode=${mode.name}');

  bool _canPresent(BuildContext context, AppLockState state) {
    if (state.locked) return false;
    if (!TickerMode.of(context)) return false;
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  Future<void> _handleFeedback(BuildContext context, AppLockState state) async {
    if (!mounted || _presentingDialog || !_canPresent(context, state)) return;
    final cubit = context.read<AppLockCubit>();
    if (!cubit.consumeFeedback(state.feedbackId)) return;

    final l10n = context.l10n;
    _presentingDialog = true;
    try {
      switch (state.feedback) {
        case SecurityFeedback.biometricEnabled:
          await AppSuccessDialog.show(
            context,
            title: l10n.securityBiometricEnabledTitle,
            message: l10n.securityBiometricEnabledMessage,
          );
        case SecurityFeedback.biometricUnavailable:
          await AppErrorDialog.show(
            context,
            message: l10n.securityAuthUnavailable,
          );
        case SecurityFeedback.none:
          return;
      }
    } finally {
      _presentingDialog = false;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<AppLockCubit, AppLockState>(
    listenWhen: (previous, next) =>
        previous.feedbackId != next.feedbackId &&
        next.feedback != SecurityFeedback.none,
    listener: (context, state) => unawaited(_handleFeedback(context, state)),
    builder: (context, state) {
      final l10n = context.l10n;
      final cubit = context.read<AppLockCubit>();
      final settings = state.settings;
      final enabled = !state.busy && !state.locked;
      return SettingsSectionCard(
        title: l10n.securityTitle,
        child: Material(
          color: context.appColors.cardPaperSurface,
          child: Column(
            children: [
              if (state.busy)
                Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.xs),
                  child: const Center(child: DaftariLoading.inline()),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const SettingsIconBox(icon: Icons.pin_outlined),
                title: Text(l10n.securityPin),
                subtitle: Text(l10n.securityPinDescription),
                value: settings.isPinEnabled,
                onChanged: !enabled
                    ? null
                    : (enabled) => _openPin(
                        context,
                        enabled ? PinFlowMode.setup : PinFlowMode.disable,
                      ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const SettingsIconBox(icon: Icons.password),
                title: Text(l10n.securityChangePin),
                trailing: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: AppSpacing.iconSmall,
                ),
                enabled: enabled && settings.isPinEnabled,
                onTap: enabled && settings.isPinEnabled
                    ? () => _openPin(context, PinFlowMode.change)
                    : null,
              ),
              if (state.biometricAvailable && settings.isPinEnabled)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const SettingsIconBox(icon: Icons.fingerprint),
                  title: Text(l10n.securityBiometrics),
                  subtitle: Text(l10n.securityBiometricsDescription),
                  value: settings.isBiometricEnabled,
                  onChanged: enabled ? cubit.setBiometric : null,
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const SettingsIconBox(icon: Icons.timer_outlined),
                title: Text(l10n.securityAutoLock),
                subtitle: Text(switch (settings.autoLockTimeout) {
                  AutoLockTimeout.immediate => l10n.securityImmediate,
                  AutoLockTimeout.oneMinute => l10n.securityOneMinute,
                  AutoLockTimeout.fiveMinutes => l10n.securityFiveMinutes,
                }),
                enabled: enabled && settings.isPinEnabled,
                trailing: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: AppSpacing.iconSmall,
                ),
                onTap: !enabled || !settings.isPinEnabled
                    ? null
                    : () => showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        isScrollControlled: true,
                        builder: (context) => SafeArea(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: AppSpacing.settingsSheetPadding,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l10n.securityAutoLock,
                                    style: context.textTheme.titleLarge,
                                  ),
                                  for (final timeout in AutoLockTimeout.values)
                                    ListTile(
                                      title: Text(switch (timeout) {
                                        AutoLockTimeout.immediate =>
                                          l10n.securityImmediate,
                                        AutoLockTimeout.oneMinute =>
                                          l10n.securityOneMinute,
                                        AutoLockTimeout.fiveMinutes =>
                                          l10n.securityFiveMinutes,
                                      }),
                                      trailing:
                                          settings.autoLockTimeout == timeout
                                          ? const Icon(Icons.check)
                                          : null,
                                      onTap: () {
                                        cubit.setAutoLock(timeout);
                                        Navigator.pop(context);
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
