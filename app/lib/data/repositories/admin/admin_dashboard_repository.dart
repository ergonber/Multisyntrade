import 'package:supabase_flutter/supabase_flutter.dart';
import '../../datasources/remote/supabase/supabase_client.dart';
import '../../models/admin/admin_stats_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminDashboardRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<AdminStatsModel> getStats() async {
    try {
      final results = await Future.wait([
        _client.from('profiles').select('id'),
        _client.from('subscriptions').select('id, plan, estado, fecha_fin'),
        _client.from('ventanas_senales').select('id, estado, resultado, created_at'),
        _client.from('ventanas_senales').select('id').eq('estado', 'activa'),
      ]);

      final allUsers = results[0] as List;
      final subs = results[1] as List;
      final ventanas = results[2] as List;
      final activeSignals = results[3] as List;

      final now = DateTime.now();

      final totalUsers = allUsers.length;
      final freeUsers = subs.where((s) => s['plan'] == 'gratis' && s['estado'] == 'activa').length;
      final vipUsers = subs.where((s) =>
          (s['plan'] == 'basico' || s['plan'] == 'pro' || s['plan'] == 'vip') &&
          s['estado'] == 'activa').length;

      final signalsToday = ventanas.where((v) {
        final created = DateTime.parse(v['created_at'] ?? now.toIso8601String());
        return created.year == now.year && created.month == now.month && created.day == now.day;
      }).length;

      final wonSignals = ventanas.where((v) => v['resultado'] == 'ganada').length;
      final lostSignals = ventanas.where((v) => v['resultado'] == 'perdida').length;
      final totalResolved = wonSignals + lostSignals;
      final effectiveness = totalResolved > 0 ? (wonSignals / totalResolved * 100) : 0.0;

      final newUsersWeek = allUsers.where((u) {
        // profiles doesn't have created_at in this query, skip
        return false;
      }).length;

      return AdminStatsModel(
        totalUsers: totalUsers,
        newUsersWeek: newUsersWeek,
        activeSubscriptions: freeUsers + vipUsers,
        signalsToday: signalsToday,
        activeSignals: activeSignals.length,
        wonSignals: wonSignals,
        lostSignals: lostSignals,
        effectiveness: effectiveness,
        vipUsers: vipUsers,
        freeUsers: freeUsers,
      );
    } catch (e) {
      throw ServerException(message: 'Error al obtener estadísticas');
    }
  }

  Future<List<Map<String, dynamic>>> getExpiringSubscriptions({int withinDays = 3}) async {
    try {
      final now = DateTime.now();
      final limit = now.add(Duration(days: withinDays));
      final response = await _client
          .from('subscriptions')
          .select('*, profiles!inner(nombre)')
          .eq('estado', 'activa')
          .lte('fecha_fin', limit.toIso8601String())
          .order('fecha_fin');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 10}) async {
    try {
      final response = await _client
          .from('ventanas_senales')
          .select('id, titulo, estado, resultado, created_at, deriv_symbol')
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
}
