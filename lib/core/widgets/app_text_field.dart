import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/spacing/app_spacing.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.isRequired = false,
    this.optionalLabel,
    this.hintText,
    this.prefix,
    this.suffix,
    this.validator,
    this.errorText,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController? controller;
  final bool isRequired;
  final String? optionalLabel;
  final String? hintText;
  final Widget? prefix;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: label,
                  children: [
                    if (isRequired)
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                  ],
                ),
                style: theme.textTheme.titleMedium,
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                optionalLabel ??
                    (isRequired ? l10n.requiredField : l10n.optional),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        Semantics(
          label: label,
          child: TextFormField(
            controller: controller,
            validator: validator,
            onChanged: onChanged,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            obscureText: obscureText,
            enabled: enabled,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: prefix,
              suffixIcon: suffix,
              errorText: errorText,
            ),
          ),
        ),
      ],
    );
  }
}
