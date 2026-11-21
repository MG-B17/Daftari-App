import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.isRequired = false,
    this.validator,
    this.onForgotPassword,
    this.textInputAction,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool isRequired;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onForgotPassword;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: widget.label,
                  children: [
                    if (widget.isRequired)
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: colors.error),
                      ),
                  ],
                ),
                style: context.textTheme.titleMedium,
              ),
            ),
            if (widget.onForgotPassword != null)
              TextButton(
                onPressed: widget.enabled ? widget.onForgotPassword : null,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.authForgotPassword,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        Semantics(
          label: widget.label,
          child: TextFormField(
            controller: widget.controller,
            validator: widget.validator,
            obscureText: _obscured,
            enabled: widget.enabled,
            textInputAction: widget.textInputAction,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                size: AppSpacing.iconMedium,
              ),
              suffixIcon: IconButton(
                tooltip: _obscured
                    ? l10n.authShowPassword
                    : l10n.authHidePassword,
                onPressed: widget.enabled
                    ? () => setState(() => _obscured = !_obscured)
                    : null,
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: AppSpacing.iconMedium,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
