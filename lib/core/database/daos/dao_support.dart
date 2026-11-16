import '../../errors/app_exception.dart';

/// Runs a database operation, preserving domain errors and translating
/// unexpected driver failures into [DatabaseException].
Future<T> runDatabaseOperation<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on AppException {
    rethrow;
  } on Exception {
    throw const DatabaseException();
  }
}

/// Trims [value] and treats blank strings as absent.
String? trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
