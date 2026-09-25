import 'package:supabase_flutter/supabase_flutter.dart';
import '../../datasources/remote/supabase/supabase_client.dart';
import '../../models/admin/operation_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminOperationsRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<OperationModel>> getOperations({String? estado}) async {
    try {
      var query = _client
          .from('auto_trade_executions')
          .select('*, profiles(nombre, email)');
      if (estado != null) {
        query = query.eq('estado', estado);
      }
      final response = await query.order('creado_en', ascending: false);
      return (response as List)
          .map((e) => OperationModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Error al obtener operaciones');
    }
  }
}
