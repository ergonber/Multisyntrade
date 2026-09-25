import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../datasources/remote/supabase/supabase_client.dart';
import '../../models/admin/admin_user_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminUsersRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<AdminUserModel>> getAllUsers() async {
    try {
      final profilesResponse = await _client
          .from('profiles')
          .select('*')
          .order('fecha_registro', ascending: false);

      final subsResponse = await _client
          .from('subscriptions')
          .select('user_id, plan, estado, fecha_fin');

      final subsByUser = <String, Map<String, dynamic>>{};
      for (final s in (subsResponse as List)) {
        final uid = s['user_id'] as String?;
        if (uid != null) {
          subsByUser[uid] = s as Map<String, dynamic>;
        }
      }

      return (profilesResponse as List).map((p) {
        final map = p as Map<String, dynamic>;
        final sub = subsByUser[map['id']];
        return AdminUserModel(
          id: map['id'] ?? '',
          nombre: map['nombre'] ?? '',
          email: map['email'],
          telefono: map['telefono'],
          fotoUrl: map['foto_url'],
          rol: map['rol'] ?? 'user',
          derivConnectionStatus: map['deriv_connection_status'] ?? 'disconnected',
          createdAt: (map['fecha_registro'] ?? map['created_at']) != null
              ? DateTime.parse((map['fecha_registro'] ?? map['created_at']))
              : null,
          plan: sub?['plan'],
          subscriptionEstado: sub?['estado'],
          subscriptionFechaFin: sub?['fecha_fin'] != null
              ? DateTime.tryParse(sub!['fecha_fin'])
              : null,
        );
      }).toList();
    } catch (e) {
      debugPrint('[AdminUsers] Error: $e');
      throw ServerException(message: 'Error al obtener usuarios: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserPayments(String userId) async {
    try {
      final response = await _client
          .from('payments')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> setRole(String userId, String role) async {
    try {
      await _client.rpc('admin_set_user_role', params: {
        'p_user_id': userId,
        'p_rol': role,
      });
    } catch (e) {
      throw ServerException(message: 'Error al cambiar rol');
    }
  }

  Future<void> toggleStatus(String userId) async {
    try {
      await _client.rpc('admin_toggle_user_status', params: {
        'p_user_id': userId,
      });
    } catch (e) {
      throw ServerException(message: 'Error al cambiar estado');
    }
  }

  Future<void> setSubscription(String userId, String plan, {DateTime? fechaFin}) async {
    try {
      await _client.rpc('admin_set_user_subscription', params: {
        'p_user_id': userId,
        'p_plan': plan,
        'p_fecha_fin': fechaFin?.toIso8601String(),
      });
    } catch (e) {
      throw ServerException(message: 'Error al asignar suscripción');
    }
  }

  Future<void> activateSubscription(String userId, {int meses = 12}) async {
    try {
      await _client.rpc('activar_suscripcion', params: {
        'p_user_id': userId,
        'p_meses': meses,
      });
    } catch (e) {
      throw ServerException(message: 'Error al activar suscripción');
    }
  }
}
