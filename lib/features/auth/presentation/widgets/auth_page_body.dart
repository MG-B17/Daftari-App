import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

class AuthPageBody extends StatelessWidget {
  const AuthPageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: AppSpacing.authMaxWidth),
      child: ListView(children: children),
    ),
  );
}
