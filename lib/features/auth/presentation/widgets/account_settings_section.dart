import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../settings/presentation/widgets/settings_icon_box.dart';
import '../../../settings/presentation/widgets/settings_section_card.dart';
import '../../domain/entities/auth_user.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import 'auth_feedback_mapper.dart';

class AccountSettingsSection extends StatelessWidget {
  const AccountSettingsSection({super.key});

  Future<void> _signOut(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: l10n.authAccountSignOut,
      message: l10n.authAccountSignOutMessage,
      confirmLabel: l10n.authAccountSignOut,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<AuthCubit?>()?.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthCubit?>();
    if (cubit == null) {
      return _AccountSectionBody(
        user: null,
        busy: false,
        onSignOut: () => _signOut(context),
      );
    }
    return AuthFlowListener(
      navigateOnVerifyEmail: false,
      popOnAuthenticated: false,
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => _AccountSectionBody(
          user: state.isAuthenticated ? state.user : null,
          busy: state.busy,
          onSignOut: () => _signOut(context),
        ),
      ),
    );
  }
}

class _AccountSectionBody extends StatelessWidget {
  const _AccountSectionBody({
    required this.user,
    required this.busy,
    required this.onSignOut,
  });

  final AuthUser? user;
  final bool busy;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = user?.email.trim();
    final signedIn = email != null && email.isNotEmpty;
    final shopName = user?.shopName?.trim();
    final emailVerified = user?.emailVerified ?? false;
    return SettingsSectionCard(
      title: l10n.authAccountTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsIconBox(
                icon: signedIn
                    ? Icons.verified_user_outlined
                    : Icons.person_outline_rounded,
              ),
              SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signedIn
                          ? l10n.authAccountLinkedTitle
                          : l10n.authAccountSignedOutTitle,
                      style: context.textTheme.titleMedium,
                    ),
                    SizedBox(height: AppSpacing.xxs),
                    Text(
                      signedIn
                          ? l10n.authAccountLinkedTo(email)
                          : l10n.authAccountSignedOutDescription,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (signedIn &&
                        shopName != null &&
                        shopName.isNotEmpty) ...[
                      SizedBox(height: AppSpacing.xxs),
                      Text(shopName, style: context.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (signedIn)
                Container(
                  padding: AppSpacing.badgePadding,
                  decoration: BoxDecoration(
                    color: emailVerified
                        ? context.appColors.paymentSurface
                        : context.appColors.creditSurface,
                    borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                  ),
                  child: Text(
                    emailVerified
                        ? l10n.authAccountVerified
                        : l10n.authAccountEmailUnverified,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: emailVerified
                          ? context.appColors.paymentColor
                          : context.appColors.creditColor,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          if (signedIn)
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: !busy,
                leading: const SettingsIconBox(icon: Icons.logout_rounded),
                title: Text(l10n.authAccountSignOut),
                subtitle: Text(l10n.authAccountLocalOnly),
                trailing: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: AppSpacing.iconSmall,
                ),
                onTap: busy ? null : onSignOut,
              ),
            )
          else ...[
            AppButton(
              label: l10n.authAccountSignIn,
              fullWidth: true,
              onPressed: busy ? null : () => context.push(AppRoutes.authLogin),
            ),
            SizedBox(height: AppSpacing.sm),
            AppButton(
              label: l10n.authAccountCreate,
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              onPressed: busy
                  ? null
                  : () => context.push(AppRoutes.authRegister),
            ),
          ],
        ],
      ),
    );
  }
}
