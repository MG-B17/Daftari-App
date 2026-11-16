import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/error_handler.dart';
import '../../domain/usecases/get_settings_usecase.dart';
import '../../domain/usecases/change_language_usecase.dart';
import '../../domain/usecases/change_theme_usecase.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(
    GetSettingsUseCase getSettings,
    this._changeLanguage,
    this._changeTheme,
    this._errorHandler,
  ) : super(_initialState(getSettings));

  final ChangeLanguageUseCase _changeLanguage;
  final ChangeThemeUseCase _changeTheme;
  final ErrorHandler _errorHandler;

  static SettingsState _initialState(GetSettingsUseCase getSettings) {
    try {
      final settings = getSettings();
      return SettingsState(
        localeCode: settings.localeCode,
        themeMode: settings.themeMode,
      );
    } catch (_) {
      return const SettingsState();
    }
  }

  Future<void> setLocaleCode(String localeCode) async {
    if (localeCode == state.localeCode) return;
    await _persist(
      state.copyWith(localeCode: localeCode),
      () => _changeLanguage(localeCode),
    );
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (themeMode == state.themeMode) return;
    await _persist(
      state.copyWith(themeMode: themeMode),
      () => _changeTheme(themeMode),
    );
  }

  Future<void> _persist(
    SettingsState next,
    Future<void> Function() write,
  ) async {
    final previous = state;
    emit(next.copyWith(hasError: false));
    try {
      await write();
    } catch (error) {
      if (!isClosed) emit(previous.copyWith(hasError: true));
      await _errorHandler.handle(error);
    }
  }
}
