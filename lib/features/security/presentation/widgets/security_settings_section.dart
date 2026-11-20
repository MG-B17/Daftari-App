import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../settings/presentation/widgets/settings_section_card.dart';
import '../../../settings/presentation/widgets/settings_icon_box.dart';
import '../../domain/entities/pin_flow_mode.dart';
import '../../domain/entities/security_settings.dart';
import '../cubit/app_lock_cubit.dart';
import '../cubit/app_lock_state.dart';

class SecuritySettingsSection extends StatelessWidget {
  const SecuritySettingsSection({super.key});

  void _openPin(BuildContext context, PinFlowMode mode) =>
      context.push<bool>('${AppRoutes.settingsPin}?mode=${mode.name}');

  @override
  Widget build(BuildContext context) => BlocBuilder<AppLockCubit, AppLockState>(
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
              if (state.busy) const LinearProgressIndicator(),
              if (state.message == SecurityMessage.unavailable)
                Text(l10n.securityAuthUnavailable),
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
