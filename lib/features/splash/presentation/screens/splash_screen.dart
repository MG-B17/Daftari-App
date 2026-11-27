import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/widgets/daftari_loading.dart';
import '../widgets/splash_branding.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished, this.hold = false});

  static const displayDuration = Duration(milliseconds: 2800);
  static const entranceDuration = Duration(milliseconds: 520);

  final VoidCallback onFinished;
  final bool hold;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _opacity;
  late final Timer _timer;
  bool _timerElapsed = false;
  bool _completed = false;
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: SplashScreen.entranceDuration,
    );
    _opacity = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _timer = Timer(SplashScreen.displayDuration, _handleTimerElapsed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      _entranceController.value = 1;
      _entranceStarted = true;
    } else if (!_entranceStarted) {
      _entranceStarted = true;
      _entranceController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.hold && _timerElapsed && !_completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _completeOnce());
    }
  }

  void _handleTimerElapsed() {
    _timerElapsed = true;
    if (!widget.hold) {
      _completeOnce();
    }
  }

  void _completeOnce() {
    if (!mounted || _completed) return;
    _completed = true;
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer.cancel();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: Column(
        children: [
          const Expanded(child: Center(child: SplashBranding())),
          Padding(
            padding: AppSpacing.splashProgressPadding,
            child: DaftariLoading.inline(
              size: AppSpacing.icon,
              semanticsLabel: context.l10n.loading,
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: context.appColors.paperBackground,
      body: MediaQuery.disableAnimationsOf(context)
          ? content
          : FadeTransition(opacity: _opacity, child: content),
    );
  }
}
