import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/error_handler.dart';
import '../../domain/usecases/change_language_usecase.dart';
import '../../domain/usecases/get_settings_usecase.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(
    GetSettingsUseCase getSettings,
    this._changeLanguage,
    this._errorHandler,
  ) : super(_initialState(getSettings)) {
    _persistedLocaleCode = state.localeCode;
  }

  final ChangeLanguageUseCase _changeLanguage;
  final ErrorHandler _errorHandler;
  late String _persistedLocaleCode;
  int _requestId = 0;
  int _persistedRequestId = 0;
  bool _latestRequestFailed = false;

  static SettingsState _initialState(GetSettingsUseCase getSettings) {
    try {
      final settings = getSettings();
      return SettingsState(localeCode: settings.localeCode);
    } catch (_) {
      return const SettingsState();
    }
  }

  Future<void> setLocaleCode(String localeCode) async {
    if (localeCode == state.localeCode) return;
    final requestId = ++_requestId;
    _latestRequestFailed = false;
    emit(state.copyWith(localeCode: localeCode, hasError: false));
    try {
      await _changeLanguage(localeCode);
      if (requestId > _persistedRequestId) {
        _persistedRequestId = requestId;
        _persistedLocaleCode = localeCode;
        if (!isClosed && _latestRequestFailed) {
          emit(
            SettingsState(
              localeCode: _persistedLocaleCode,
              hasError: state.hasError,
            ),
          );
        }
      }
    } catch (error) {
      if (!isClosed && requestId == _requestId) {
        _latestRequestFailed = true;
        emit(SettingsState(localeCode: _persistedLocaleCode, hasError: true));
      }
      await _errorHandler.handle(error);
    }
  }
}
