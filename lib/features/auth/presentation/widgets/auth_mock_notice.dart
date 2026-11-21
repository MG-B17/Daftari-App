import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class AuthMockNotice extends StatelessWidget {
  const AuthMockNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.visibility_outlined,
        size: AppSpacing.iconSmall,
        color: context.colorScheme.onSurfaceVariant,
      ),
      SizedBox(width: AppSpacing.xs),
      Flexible(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}
