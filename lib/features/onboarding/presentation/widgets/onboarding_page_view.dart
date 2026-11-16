import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';
import 'onboarding_copy.dart';
import 'onboarding_page_content.dart';

class OnboardingPageView extends StatefulWidget {
  const OnboardingPageView({super.key});

  @override
  State<OnboardingPageView> createState() => _OnboardingPageViewState();
}

class _OnboardingPageViewState extends State<OnboardingPageView> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: context.read<OnboardingCubit>().state.pageIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listenWhen: (previous, current) =>
          previous.pageIndex != current.pageIndex,
      listener: (context, state) {
        if (_controller.hasClients &&
            _controller.page?.round() != state.pageIndex) {
          _controller.animateToPage(
            state.pageIndex,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
          );
        }
      },
      buildWhen: (previous, current) => previous.isSaving != current.isSaving,
      builder: (context, state) => PageView.builder(
        controller: _controller,
        physics: state.isSaving ? const NeverScrollableScrollPhysics() : null,
        onPageChanged: context.read<OnboardingCubit>().onPageChanged,
        itemCount: OnboardingState.pageCount,
        itemBuilder: (context, index) => OnboardingPageContent(
          title: l10n.onboardingTitles[index],
          description: l10n.onboardingDescriptions[index],
        ),
      ),
    );
  }
}
