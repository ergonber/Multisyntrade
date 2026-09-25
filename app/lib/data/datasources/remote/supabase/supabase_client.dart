import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../config/app_config.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient? _client;

  static SupabaseClient get client {
    if (_client == null) {
      throw StateError('SupabaseService not initialized. Call init() first.');
    }
    return _client!;
  }

  static Future<void> init() async {
    AppConfig.validate();
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
    );
    _client = Supabase.instance.client;
  }

  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;
  static bool get isAuthenticated => currentSession != null;
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}
