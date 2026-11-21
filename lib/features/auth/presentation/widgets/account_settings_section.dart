import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../settings/presentation/widgets/settings_icon_box.dart';
import '../../../settings/presentation/widgets/settings_section_card.dart';

class AccountSettingsSection extends StatelessWidget {
  const AccountSettingsSection({
    super.key,
    this.mockEmail,
    this.mockShopName,
    this.mockEmailVerified = false,
  });

  /// Preview-only session data. Task 4 replaces this with `AuthCubit` state.
  final String? mockEmail;
  final String? mockShopName;
  final bool mockEmailVerified;

  Future<void> _signOut(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: l10n.authAccountSignOut,
      message: l10n.authAccountSignOutMessage,
      confirmLabel: l10n.authAccountSignOut,
    );
    if (!confirmed || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.authAccountMockNotice)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = mockEmail?.trim();
    final signedIn = email != null && email.isNotEmpty;
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
                    if (signedIn && mockShopName != null) ...[
                      SizedBox(height: AppSpacing.xxs),
                      Text(mockShopName!, style: context.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (signedIn)
                Container(
                  padding: AppSpacing.badgePadding,
                  decoration: BoxDecoration(
                    color: mockEmailVerified
                        ? context.appColors.paymentSurface
                        : context.appColors.creditSurface,
                    borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                  ),
                  child: Text(
                    mockEmailVerified
                        ? l10n.authAccountVerified
                        : l10n.authAccountEmailUnverified,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: mockEmailVerified
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
                leading: const SettingsIconBox(icon: Icons.logout_rounded),
                title: Text(l10n.authAccountSignOut),
                subtitle: Text(l10n.authAccountLocalOnly),
                trailing: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  size: AppSpacing.iconSmall,
                ),
                onTap: () => _signOut(context),
              ),
            )
          else ...[
            AppButton(
              label: l10n.authAccountSignIn,
              fullWidth: true,
              onPressed: () => context.push(AppRoutes.authLogin),
            ),
            SizedBox(height: AppSpacing.sm),
            AppButton(
              label: l10n.authAccountCreate,
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              onPressed: () => context.push(AppRoutes.authRegister),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              l10n.authAccountMockNotice,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
