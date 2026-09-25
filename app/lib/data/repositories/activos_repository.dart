import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/remote/supabase/supabase_client.dart';
import '../models/activo_model.dart';
import '../../core/errors/app_exception.dart';

class ActivosRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<ActivoModel>> getActivos() async {
    try {
      final response = await _client
          .from('activos')
          .select()
          .eq('habilitado', true)
          .order('nombre');
      return (response as List).map((e) => ActivoModel.fromMap(e)).toList();
    } catch (e) {
      throw ServerException(message: 'Error al obtener activos');
    }
  }

  Future<List<ActivoModel>> getAllActivos() async {
    try {
      final response = await _client
          .from('activos')
          .select()
          .order('nombre');
      return (response as List).map((e) => ActivoModel.fromMap(e)).toList();
    } catch (e) {
      throw ServerException(message: 'Error al obtener activos');
    }
  }

  Future<ActivoModel?> getActivoBySymbol(String symbol) async {
    try {
      final response = await _client
          .from('activos')
          .select()
          .eq('deriv_symbol', symbol)
          .maybeSingle();
      if (response == null) return null;
      return ActivoModel.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> syncActivosFromDeriv() async {
    try {
      await _client.functions.invoke('deriv-sync-activos');
    } catch (e) {
      throw ServerException(message: 'Error al sincronizar activos con Deriv');
    }
  }
}
