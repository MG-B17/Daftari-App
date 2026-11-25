import 'main.dart' as app;

/// Explicit debug entrypoint for Marionette UI inspection runs
/// (`flutter run -t lib/main_marionette.dart`).
Future<void> main() => app.main(useMarionetteBinding: true);
