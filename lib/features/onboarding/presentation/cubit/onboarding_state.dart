import 'package:equatable/equatable.dart';

class OnboardingState extends Equatable {
  const OnboardingState({
    this.pageIndex = 0,
    this.isSaving = false,
    this.isCompleted = false,
    this.hasError = false,
  });

  static const pageCount = 3;

  final int pageIndex;
  final bool isSaving;
  final bool isCompleted;
  final bool hasError;

  bool get isLastPage => pageIndex == pageCount - 1;

  @override
  List<Object> get props => [pageIndex, isSaving, isCompleted, hasError];
}
