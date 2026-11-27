import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';

class OnboardingNextButton extends StatelessWidget {
  const OnboardingNextButton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: AppSpacing.introNextButtonPadding,
    child: BlocBuilder<OnboardingCubit, OnboardingState>(
      buildWhen: (previous, current) =>
          previous.isLastPage != current.isLastPage ||
          previous.isSaving != current.isSaving ||
          previous.isCompleted != current.isCompleted,
      builder: (context, state) {
        final l10n = context.l10n;
        final cubit = context.read<OnboardingCubit>();
        return AppButton(
          key: const ValueKey('onboarding-next'),
          label: state.isLastPage ? l10n.onboardingStart : l10n.onboardingNext,
          icon: state.isLastPage ? null : Icons.arrow_forward_rounded,
          fullWidth: true,
          isLoading: state.isSaving,
          onPressed: state.isCompleted
              ? null
              : state.isLastPage
              ? cubit.completeOnboarding
              : cubit.nextPage,
        );
      },
    ),
  );
}
