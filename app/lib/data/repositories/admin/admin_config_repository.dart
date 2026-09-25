import 'package:supabase_flutter/supabase_flutter.dart';
import '../../datasources/remote/supabase/supabase_client.dart';
import '../../models/admin/app_config_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminConfigRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<AppConfigModel> getConfig() async {
    try {
      final response = await _client
          .from('app_config')
          .select()
          .single();
      return AppConfigModel.fromMap(response);
    } catch (e) {
      return const AppConfigModel();
    }
  }

  Future<void> updateConfig({
    bool? maintenanceMode,
    String? maintenanceMessage,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (maintenanceMode != null) updates['maintenance_mode'] = maintenanceMode;
      if (maintenanceMessage != null) updates['maintenance_message'] = maintenanceMessage;
      await _client.from('app_config').update(updates).eq('id', 1);
    } catch (e) {
      throw ServerException(message: 'Error al actualizar configuración');
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? nombre,
    String? fotoUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (nombre != null) updates['nombre'] = nombre;
      if (fotoUrl != null) updates['foto_url'] = fotoUrl;
      await _client.from('profiles').update(updates).eq('id', userId);
    } catch (e) {
      throw ServerException(message: 'Error al actualizar perfil');
    }
  }
}
