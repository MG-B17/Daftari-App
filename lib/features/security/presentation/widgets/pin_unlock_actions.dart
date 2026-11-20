import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../cubit/app_lock_cubit.dart';
import '../cubit/app_lock_state.dart';
import '../cubit/pin_flow_cubit.dart';
import 'biometric_unlock_button.dart';

/// Unlock alternatives shown below the keypad in the unlock flow.
class PinUnlockActions extends StatelessWidget {
  const PinUnlockActions({
    super.key,
    required this.flow,
    required this.security,
  });

  final PinFlowCubit flow;
  final AppLockState security;

  Future<void> _recover(BuildContext context) async {
    if (security.deviceLockAvailable) {
      await flow.recover();
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.securityRecoveryTitle),
        content: Text(context.l10n.securityRecoveryGuidance),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          if (security.biometricAvailable &&
              security.settings.isBiometricEnabled)
            BiometricUnlockButton(
              onPressed: flow.enabled
                  ? () => context.read<AppLockCubit>().biometric()
                  : null,
            ),
          TextButton(
            onPressed:
                security.busy || security.message == SecurityMessage.storage
                ? null
                : () => _recover(context),
            child: Text(l10n.securityForgotPin),
          ),
        ],
      ),
    );
  }
}
