import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/spacing/app_spacing.dart';

enum DaftariLoadingVariant { inline, screen }

class DaftariLoading extends StatelessWidget {
  const DaftariLoading({
    super.key,
    this.variant = DaftariLoadingVariant.screen,
    this.size,
    this.color,
    this.message,
    this.semanticsLabel,
  });

  const DaftariLoading.inline({
    super.key,
    this.size,
    this.color,
    this.semanticsLabel,
  }) : variant = DaftariLoadingVariant.inline,
       message = null;

  const DaftariLoading.screen({
    super.key,
    this.size,
    this.color,
    this.message,
    this.semanticsLabel,
  }) : variant = DaftariLoadingVariant.screen;

  static const assetPath = 'assets/lottie/loading.json';

  final DaftariLoadingVariant variant;
  final double? size;
  final Color? color;
  final String? message;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dimension =
        size ??
        switch (variant) {
          DaftariLoadingVariant.inline => AppSpacing.loadingInlineSize,
          DaftariLoadingVariant.screen => AppSpacing.loadingScreenSize,
        };
    final resolvedColor = color ?? theme.colorScheme.primary;
    final fallbackLabel = l10n?.loading ?? 'Loading';
    final staticVisual = _StaticLoadingVisual(
      dimension: dimension,
      color: resolvedColor,
      showBadge: variant == DaftariLoadingVariant.screen,
    );

    final visual = SizedBox.square(
      dimension: dimension,
      child: reduceMotion
          ? staticVisual
          : Lottie.asset(
              assetPath,
              width: dimension,
              height: dimension,
              fit: BoxFit.contain,
              repeat: true,
              delegates: LottieDelegates(
                values: [
                  ValueDelegate.strokeColor(const ['**'], value: resolvedColor),
                ],
              ),
              frameBuilder: (_, child, composition) =>
                  composition == null ? staticVisual : child,
              errorBuilder: (_, _, _) => staticVisual,
            ),
    );

    if (variant == DaftariLoadingVariant.inline) {
      return Semantics(
        label: semanticsLabel ?? fallbackLabel,
        liveRegion: true,
        excludeSemantics: true,
        child: visual,
      );
    }

    final hasMessage = message != null && message!.isNotEmpty;
    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Semantics(
          label: semanticsLabel ?? (hasMessage ? null : fallbackLabel),
          liveRegion: true,
          excludeSemantics: semanticsLabel != null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: visual),
              if (hasMessage) ...[
                SizedBox(height: AppSpacing.md),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StaticLoadingVisual extends StatelessWidget {
  const _StaticLoadingVisual({
    required this.dimension,
    required this.color,
    required this.showBadge,
  });

  final double dimension;
  final Color color;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    if (!showBadge) {
      return Center(
        child: Icon(
          Icons.hourglass_top_rounded,
          size: dimension * 0.85,
          color: color,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.hourglass_top_rounded,
          size: (dimension * 0.45).clamp(20.0, 48.0),
          color: color,
        ),
      ),
    );
  }
}
