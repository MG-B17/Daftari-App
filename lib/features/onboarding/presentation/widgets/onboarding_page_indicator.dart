import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../cubit/onboarding_state.dart';
import '../cubit/onboarding_cubit.dart';
import 'onboarding_copy.dart';

class OnboardingPageIndicator extends StatelessWidget {
  const OnboardingPageIndicator({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: BlocBuilder<OnboardingCubit, OnboardingState>(
      buildWhen: (previous, current) => previous.pageIndex != current.pageIndex,
      builder: (context, state) => _PageIndicator(
        pageIndex: state.pageIndex,
        title: context.l10n.onboardingTitles[state.pageIndex],
      ),
    ),
  );
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.pageIndex, required this.title});

  final int pageIndex;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final label = context.l10n.onboardingPageLabel(
      pageIndex + 1,
      OnboardingState.pageCount,
      title,
    );
    return Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                OnboardingState.pageCount,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: index == pageIndex
                      ? AppSpacing.indicatorActiveWidth
                      : AppSpacing.indicatorDot,
                  height: AppSpacing.indicatorDot,
                  margin: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: index == pageIndex
                        ? colors.primary
                        : colors.outlineVariant,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.compact,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(AppSpacing.largeRadius),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: context.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
