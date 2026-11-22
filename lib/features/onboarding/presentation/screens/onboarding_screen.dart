import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/widgets/auth_feedback_mapper.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';
import '../widgets/onboarding_app_bar.dart';
import '../widgets/onboarding_next_button.dart';
import '../widgets/onboarding_page_indicator.dart';
import '../widgets/onboarding_page_view.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => AuthFlowListener(
    navigateOnVerifyEmail: false,
    popOnAuthenticated: false,
    child: BlocListener<OnboardingCubit, OnboardingState>(
      listenWhen: (previous, current) =>
          current.isCompleted || previous.hasError != current.hasError,
      listener: (context, state) {
        if (state.isCompleted) {
          context.go(AppRoutes.root);
        } else if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.onboardingStorageError)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: context.appColors.paperBackground,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: AppSpacing.introMaxWidth),
              child: const Column(
                children: [
                  OnboardingAppBar(),
                  Expanded(child: OnboardingPageView()),
                  OnboardingPageIndicator(),
                  OnboardingNextButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
