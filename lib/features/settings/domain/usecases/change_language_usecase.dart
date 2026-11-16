import '../repositories/settings_repository.dart';

/// Persists a new application language.
class ChangeLanguageUseCase {
  const ChangeLanguageUseCase(this._repository);

  final SettingsRepository _repository;

  Future<void> call(String localeCode) => _repository.setLocaleCode(localeCode);
}
