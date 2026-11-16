import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../widgets/splash_branding.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  static const displayDuration = Duration(milliseconds: 1200);

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen.displayDuration, () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appColors.paperBackground,
    body: SafeArea(
      child: Column(
        children: [
          const Expanded(child: Center(child: SplashBranding())),
          Padding(
            padding: AppSpacing.splashProgressPadding,
            child: SizedBox.square(
              dimension: AppSpacing.icon,
              child: CircularProgressIndicator(
                strokeWidth: AppSpacing.progressStroke,
                semanticsLabel: context.l10n.loading,
                backgroundColor: context.colorScheme.outlineVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
