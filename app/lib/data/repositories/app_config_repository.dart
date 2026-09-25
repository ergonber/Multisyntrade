import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/remote/supabase/supabase_client.dart';
import '../../core/errors/app_exception.dart';

class AppConfigRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<bool> isMaintenanceMode() async {
    try {
      final response = await _client
          .from('app_config')
          .select('mantenimiento')
          .eq('id', 1)
          .maybeSingle();
      return response?['mantenimiento'] ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getMaintenanceMessage() async {
    try {
      final response = await _client
          .from('app_config')
          .select('mensaje_mantenimiento')
          .eq('id', 1)
          .maybeSingle();
      return response?['mensaje_mantenimiento'];
    } catch (e) {
      return null;
    }
  }
}
