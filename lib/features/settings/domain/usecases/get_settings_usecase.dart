import '../repositories/settings_repository.dart';

/// Snapshot of the persisted settings consumed by the presentation layer.
typedef SettingsSnapshot = ({String localeCode});

/// Reads the persisted language preference.
class GetSettingsUseCase {
  const GetSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  SettingsSnapshot call() => (localeCode: _repository.localeCode);
}
