import 'package:supabase_flutter/supabase_flutter.dart';
import '../../datasources/remote/supabase/supabase_client.dart';
import '../../models/admin/finance_summary_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminFinanceRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<FinanceSummaryModel> getSummary() async {
    try {
      final results = await Future.wait([
        _client.from('payments').select('id, monto, estado, created_at'),
        _client.from('subscriptions').select('id, plan, estado, fecha_fin'),
      ]);

      final payments = results[0] as List;
      final subs = results[1] as List;

      final totalRevenue = payments
          .where((p) => p['estado'] == 'completado')
          .fold<double>(0, (sum, p) => sum + ((p['monto'] ?? 0).toDouble()));

      final activeSubs = subs.where((s) => s['estado'] == 'activa').length;
      final pendingPayments = payments.where((p) => p['estado'] == 'pendiente').length;

      final recentPayments = payments
          .take(10)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      return FinanceSummaryModel(
        totalRevenue: totalRevenue,
        netRevenue: totalRevenue * 0.85,
        commissions: totalRevenue * 0.15,
        activeSubscriptions: activeSubs,
        pendingPayments: pendingPayments,
        recentPayments: recentPayments,
      );
    } catch (e) {
      throw ServerException(message: 'Error al obtener resumen financiero');
    }
  }

  Future<List<Map<String, dynamic>>> getPayments({int limit = 50}) async {
    try {
      final response = await _client
          .from('payments')
          .select('*, profiles!inner(nombre)')
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
}
