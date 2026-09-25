import 'package:supabase_flutter/supabase_flutter.dart';
import '../../datasources/remote/supabase/supabase_client.dart';
import '../../models/ventana_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminSignalsRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<VentanaModel>> getAllVentanas() async {
    try {
      final response = await _client
          .from('ventanas_senales')
          .select()
          .order('created_at', ascending: false);
      return (response as List)
          .map((e) => VentanaModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Error al obtener ventanas');
    }
  }

  /// Stream de Realtime + carga inicial de las ventanas_senales del MT5.
  Stream<List<Map<String, dynamic>>> streamVentanas() {
    return _client
        .from('ventanas_senales')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }
}
