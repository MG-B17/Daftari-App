import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../errors/error_handler.dart';
import '../services/local_storage_service.dart';
import 'theme_switcher_state.dart';

class ThemeSwitcherCubit extends Cubit<ThemeSwitcherState> {
  ThemeSwitcherCubit(this._localStorage, this._errorHandler)
    : super(_initialState(_localStorage)) {
    _persistedThemeMode = state.themeMode;
  }

  final LocalStorageService _localStorage;
  final ErrorHandler _errorHandler;
  late ThemeMode _persistedThemeMode;
  int _requestId = 0;

  static ThemeSwitcherState _initialState(LocalStorageService localStorage) {
    try {
      return ThemeSwitcherState(themeMode: localStorage.themeMode);
    } catch (_) {
      return const ThemeSwitcherState();
    }
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (themeMode == state.themeMode) return;
    final requestId = ++_requestId;
    emit(state.copyWith(themeMode: themeMode, hasError: false));
    try {
      await _localStorage.setThemeMode(themeMode);
      if (requestId == _requestId) {
        _persistedThemeMode = themeMode;
      }
    } catch (error) {
      if (!isClosed && requestId == _requestId) {
        emit(
          ThemeSwitcherState(themeMode: _persistedThemeMode, hasError: true),
        );
      }
      await _errorHandler.handle(error);
    }
  }
}
