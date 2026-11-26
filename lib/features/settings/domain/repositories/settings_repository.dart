/// Persistence contract for user-adjustable settings.
///
/// Implementations may throw exceptions when storage is
/// unavailable; presentation layers convert those failures into UI state.
abstract interface class SettingsRepository {
  /// The persisted language code (`'ar'` or `'en'`).
  String get localeCode;

  /// Persists [localeCode], throwing when storage rejects the write.
  Future<void> setLocaleCode(String localeCode);
}
