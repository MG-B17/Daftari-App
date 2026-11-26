import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show Locale;

class SettingsState extends Equatable {
  const SettingsState({this.localeCode = 'ar', this.hasError = false});

  final String localeCode;
  final bool hasError;

  Locale get locale => Locale(localeCode);
  bool get isArabic => localeCode == 'ar';

  SettingsState copyWith({String? localeCode, bool? hasError}) => SettingsState(
    localeCode: localeCode ?? this.localeCode,
    hasError: hasError ?? this.hasError,
  );

  @override
  List<Object> get props => [localeCode, hasError];
}
