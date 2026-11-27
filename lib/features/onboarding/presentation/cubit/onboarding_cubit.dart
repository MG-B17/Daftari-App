import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/loacl_storage/local_storage_service.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit(this._localStorage) : super(const OnboardingState());

  final LocalStorageService _localStorage;

  void onPageChanged(int index) {
    if (index < 0 ||
        index >= OnboardingState.pageCount ||
        state.isSaving ||
        state.isCompleted) {
      return;
    }
    emit(OnboardingState(pageIndex: index));
  }

  void nextPage() {
    if (!state.isLastPage) onPageChanged(state.pageIndex + 1);
  }

  Future<void> completeOnboarding() async {
    if (state.isSaving || state.isCompleted) return;
    final page = state.pageIndex;
    emit(OnboardingState(pageIndex: page, isSaving: true));
    try {
      await _localStorage.setOnboardingCompleted(true);
      if (!isClosed) {
        emit(OnboardingState(pageIndex: page, isCompleted: true));
      }
    } catch (_) {
      if (!isClosed) emit(OnboardingState(pageIndex: page, hasError: true));
    }
  }
}
