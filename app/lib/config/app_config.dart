import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static String get supabaseUrl => const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static String get supabaseAnonKey => const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static String get appUrl {
    final envUrl = const String.fromEnvironment('APP_URL', defaultValue: '');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) return 'https://multisyntrade.vercel.app';
    return 'syntrade://auth-callback';
  }

  static bool get isProduction => kReleaseMode;
  static bool get isDevelopment => kDebugMode;

  /// Acceso oculto al panel: requiere abrir la URL con `?admin=1`.
  /// (Query param: se lee de forma confiable en web.)
  static bool get isAdminEntry {
    try {
      return Uri.base.queryParameters['admin'] == '1';
    } catch (_) {
      return false;
    }
  }

  static void validate() {
    assert(
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty,
      'SUPABASE_URL and SUPABASE_ANON_KEY must be provided via --dart-define',
    );
  }
}
