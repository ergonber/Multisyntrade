import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/remote/supabase/supabase_client.dart';
import '../models/profile_model.dart';
import '../../../core/errors/app_exception.dart';

class ProfileRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<ProfileModel> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return ProfileModel.fromMap(response);
    } catch (e) {
      throw ServerException(message: 'Error al obtener perfil');
    }
  }

  Future<ProfileModel> updateProfile(String userId, Map<String, dynamic> data) async {
    try {
      final response = await _client
          .from('profiles')
          .update(data)
          .eq('id', userId)
          .select()
          .single();
      return ProfileModel.fromMap(response);
    } catch (e) {
      throw ServerException(message: 'Error al actualizar perfil');
    }
  }

  Future<void> setCapitalInicial(String userId, double capital) async {
    try {
      await _client.rpc('set_capital_inicial', params: {
        'p_capital': capital,
      });
    } catch (e) {
      throw ServerException(message: 'Error al configurar capital');
    }
  }

  Future<void> setRiskProfile(String userId, double riskPercentage) async {
    try {
      await _client.rpc('set_risk_profile', params: {
        'p_risk_percentage': riskPercentage,
      });
    } catch (e) {
      throw ServerException(message: 'Error al configurar riesgo');
    }
  }

  Future<void> updateFcmToken(String userId, String token) async {
    try {
      await _client.rpc('update_fcm_token', params: {
        'p_token': token,
      });
    } catch (e) {
      // Non-critical, don't throw
    }
  }

  Future<void> updateNotificationPrefs(String userId, {
    bool? nuevaOperacion,
    bool? resultado,
    bool? promociones,
    bool? sistema,
    bool? objetivos,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (nuevaOperacion != null) data['notif_nueva_operacion'] = nuevaOperacion;
      if (resultado != null) data['notif_resultado'] = resultado;
      if (promociones != null) data['notif_promociones'] = promociones;
      if (sistema != null) data['notif_sistema'] = sistema;
      if (objetivos != null) data['notif_objetivos'] = objetivos;
      await _client.from('profiles').update(data).eq('id', userId);
    } catch (e) {
      throw ServerException(message: 'Error al actualizar notificaciones');
    }
  }
}
