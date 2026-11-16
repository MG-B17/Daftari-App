import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:daftariapp/core/services/local_storage_service.dart';
import 'package:daftariapp/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:daftariapp/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Storage extends Mock implements LocalStorageService {}

void main() {
  late _Storage storage;
  setUp(() {
    storage = _Storage();
    when(() => storage.setOnboardingCompleted(true)).thenAnswer((_) async {});
  });

  test('initial state and value equality', () async {
    final cubit = OnboardingCubit(storage);
    expect(cubit.state, const OnboardingState());
    expect(cubit.state.isLastPage, isFalse);
    expect(const OnboardingState(pageIndex: 2).isLastPage, isTrue);
    await cubit.close();
  });

  blocTest<OnboardingCubit, OnboardingState>(
    'nextPage stops at page 3 and invalid indices are ignored',
    build: () => OnboardingCubit(storage),
    act: (cubit) {
      cubit.onPageChanged(-1);
      cubit.onPageChanged(3);
      cubit.nextPage();
      cubit.nextPage();
      cubit.nextPage();
      cubit.onPageChanged(0);
    },
    expect: () => [
      const OnboardingState(pageIndex: 1),
      const OnboardingState(pageIndex: 2),
      const OnboardingState(),
    ],
    verify: (_) => verifyNever(() => storage.setOnboardingCompleted(true)),
  );

  for (final page in [0, 2]) {
    blocTest<OnboardingCubit, OnboardingState>(
      'completion on page $page persists once',
      build: () => OnboardingCubit(storage),
      seed: () => OnboardingState(pageIndex: page),
      act: (cubit) async {
        await cubit.completeOnboarding();
        await cubit.completeOnboarding();
        cubit.nextPage();
      },
      expect: () => [
        OnboardingState(pageIndex: page, isSaving: true),
        OnboardingState(pageIndex: page, isCompleted: true),
      ],
      verify: (_) =>
          verify(() => storage.setOnboardingCompleted(true)).called(1),
    );
  }

  blocTest<OnboardingCubit, OnboardingState>(
    'storage failure stays on current page and supports retry',
    build: () {
      when(() => storage.setOnboardingCompleted(true))
          .thenThrow(Exception('storage unavailable'));
      return OnboardingCubit(storage);
    },
    seed: () => const OnboardingState(pageIndex: 2),
    act: (cubit) async {
      await cubit.completeOnboarding();
      when(() => storage.setOnboardingCompleted(true)).thenAnswer((_) async {});
      await cubit.completeOnboarding();
    },
    expect: () => [
      const OnboardingState(pageIndex: 2, isSaving: true),
      const OnboardingState(pageIndex: 2, hasError: true),
      const OnboardingState(pageIndex: 2, isSaving: true),
      const OnboardingState(pageIndex: 2, isCompleted: true),
    ],
  );

  test('pending save prevents duplicate writes and page changes', () async {
    final pending = Completer<void>();
    when(() => storage.setOnboardingCompleted(true))
        .thenAnswer((_) => pending.future);
    final cubit = OnboardingCubit(storage);
    final save = cubit.completeOnboarding();
    await cubit.completeOnboarding();
    cubit.nextPage();
    expect(cubit.state, const OnboardingState(isSaving: true));
    verify(() => storage.setOnboardingCompleted(true)).called(1);
    await cubit.close();
    pending.complete();
    await save;
  });
}
