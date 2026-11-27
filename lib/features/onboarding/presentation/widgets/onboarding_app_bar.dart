import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing/app_spacing.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';

class OnboardingAppBar extends StatelessWidget {
  const OnboardingAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: AppSpacing.introAppBarPadding,
      child: Row(
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: AppSpacing.iconSmall,
            color: context.colorScheme.primary,
          ),
          SizedBox(width: AppSpacing.tight),
          Expanded(
            child: Text(
              l10n.appTitle,
              style: context.textTheme.titleSmall?.copyWith(
                color: context.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          BlocBuilder<OnboardingCubit, OnboardingState>(
            buildWhen: (previous, current) =>
                previous.isSaving != current.isSaving ||
                previous.isCompleted != current.isCompleted,
            builder: (context, state) => TextButton(
              key: const ValueKey('onboarding-skip'),
              onPressed: state.isSaving || state.isCompleted
                  ? null
                  : context.read<OnboardingCubit>().completeOnboarding,
              child: Text(l10n.onboardingSkip),
            ),
          ),
        ],
      ),
    );
  }
}
