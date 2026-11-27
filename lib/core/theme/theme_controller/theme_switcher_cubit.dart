import 'package:daftariapp/core/theme/theme_controller/theme_switcher_state.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../errors/error_handler.dart';
import '../../services/loacl_storage/local_storage_service.dart';

class ThemeSwitcherCubit extends Cubit<ThemeSwitcherState> {
  ThemeSwitcherCubit(this._localStorage, this._errorHandler)
    : super(_initialState(_localStorage)) {
    _persistedThemeMode = state.themeMode;
  }

  final LocalStorageService _localStorage;
  final ErrorHandler _errorHandler;
  late ThemeMode _persistedThemeMode;
  int _requestId = 0;
  int _persistedRequestId = 0;
  bool _latestRequestFailed = false;

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
    _latestRequestFailed = false;
    emit(state.copyWith(themeMode: themeMode, hasError: false));
    try {
      await _localStorage.setThemeMode(themeMode);
      if (requestId > _persistedRequestId) {
        _persistedRequestId = requestId;
        _persistedThemeMode = themeMode;
        if (!isClosed && _latestRequestFailed) {
          emit(
            ThemeSwitcherState(
              themeMode: _persistedThemeMode,
              hasError: state.hasError,
            ),
          );
        }
      }
    } catch (error) {
      if (!isClosed && requestId == _requestId) {
        _latestRequestFailed = true;
        emit(
          ThemeSwitcherState(themeMode: _persistedThemeMode, hasError: true),
        );
      }
      await _errorHandler.handle(error);
    }
  }
}
