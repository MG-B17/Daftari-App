import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;

class SettingsState extends Equatable {
  const SettingsState({
    this.localeCode = 'ar',
    this.themeMode = ThemeMode.system,
    this.hasError = false,
  });

  final String localeCode;
  final ThemeMode themeMode;
  final bool hasError;

  Locale get locale => Locale(localeCode);
  bool get isArabic => localeCode == 'ar';

  SettingsState copyWith({
    String? localeCode,
    ThemeMode? themeMode,
    bool? hasError,
  }) => SettingsState(
    localeCode: localeCode ?? this.localeCode,
    themeMode: themeMode ?? this.themeMode,
    hasError: hasError ?? this.hasError,
  );

  @override
  List<Object> get props => [localeCode, themeMode, hasError];
}
