import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'secure_gotrue_storage.dart';

const _envSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _envSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

typedef SupabaseInitializer = Future<sb.SupabaseClient> Function({
  required String url,
  required String anonKey,
  required FlutterSecureStorage secureStorage,
});

/// Initializes Supabase from `--dart-define-from-file` values and degrades
/// safely to unconfigured/offline mode when credentials are absent or invalid.
class SupabaseBootstrap {
  SupabaseBootstrap({
    String? url,
    String? anonKey,
    SupabaseInitializer? initializer,
  }) : _url = (url ?? _envSupabaseUrl).trim(),
       _anonKey = (anonKey ?? _envSupabaseAnonKey).trim(),
       _initializer = initializer ?? _defaultInitialize;

  static const authCallbackUrl = 'com.mgb.daftari://auth-callback';

  final String _url;
  final String _anonKey;
  final SupabaseInitializer _initializer;

  sb.SupabaseClient? _client;
  bool _initialized = false;

  sb.SupabaseClient? get client => _client;
  bool get isConfigured => _client != null;

  bool get hasValidConfig {
    if (_url.isEmpty || _anonKey.isEmpty) return false;
    final uri = Uri.tryParse(_url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        !uri.host.contains('your-project-ref');
  }

  Future<bool> initialize(FlutterSecureStorage secureStorage) async {
    if (_initialized) return isConfigured;
    _initialized = true;
    if (!hasValidConfig) return false;

    try {
      _client = await _initializer(
        url: _url,
        anonKey: _anonKey,
        secureStorage: secureStorage,
      );
      return true;
    } catch (_) {
      _client = null;
      return false;
    }
  }

  static Future<sb.SupabaseClient> _defaultInitialize({
    required String url,
    required String anonKey,
    required FlutterSecureStorage secureStorage,
  }) async {
    final instance = await sb.Supabase.initialize(
      url: url,
      publishableKey: anonKey,
      debug: false,
      authOptions: sb.FlutterAuthClientOptions(
        authFlowType: sb.AuthFlowType.pkce,
        pkceAsyncStorage: SecureGotrueStorage(secureStorage),
        localStorage: SecureSupabaseLocalStorage(secureStorage),
      ),
    );
    return instance.client;
  }
}
