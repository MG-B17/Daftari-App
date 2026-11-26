import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show ThemeMode;

class ThemeSwitcherState extends Equatable {
  const ThemeSwitcherState({
    this.themeMode = ThemeMode.system,
    this.hasError = false,
  });

  final ThemeMode themeMode;
  final bool hasError;

  ThemeSwitcherState copyWith({ThemeMode? themeMode, bool? hasError}) =>
      ThemeSwitcherState(
        themeMode: themeMode ?? this.themeMode,
        hasError: hasError ?? this.hasError,
      );

  @override
  List<Object> get props => [themeMode, hasError];
}
