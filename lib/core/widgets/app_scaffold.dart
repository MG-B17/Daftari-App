import 'package:flutter/material.dart';

import '../theme/spacing/app_spacing.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.padding,
    this.backgroundColor,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
  });

  final Widget body;
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: backgroundColor,
    appBar: title == null
        ? null
        : AppBar(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title!),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            actions: actions,
            leading: leading,
          ),
    body: SafeArea(
      child: Padding(padding: padding ?? AppSpacing.pagePadding, child: body),
    ),
    floatingActionButton: floatingActionButton,
    floatingActionButtonLocation: floatingActionButtonLocation,
    bottomNavigationBar: bottomNavigationBar,
  );
}
