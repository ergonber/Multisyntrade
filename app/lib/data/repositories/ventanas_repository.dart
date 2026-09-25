import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/remote/supabase/supabase_client.dart';
import '../models/ventana_model.dart';
import '../../../core/errors/app_exception.dart';

class VentanasRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<VentanaModel>> getActiveVentanas() async {
    try {
      final response = await _client
          .from('ventanas_senales')
          .select()
          .eq('estado', 'activa')
          .order('fecha_inicio', ascending: false);
      return (response as List).map((e) => VentanaModel.fromMap(e)).toList();
    } catch (e) {
      throw ServerException(message: 'Error al obtener ventanas activas');
    }
  }

  Future<List<VentanaModel>> getScheduledVentanas() async {
    try {
      final response = await _client
          .from('ventanas_senales')
          .select()
          .eq('estado', 'programada')
          .order('fecha_inicio', ascending: false);
      return (response as List).map((e) => VentanaModel.fromMap(e)).toList();
    } catch (e) {
      throw ServerException(message: 'Error al obtener ventanas programadas');
    }
  }

  Future<List<VentanaModel>> getClosedVentanas() async {
    try {
      final response = await _client
          .from('ventanas_senales')
          .select()
          .eq('estado', 'cerrada')
          .order('fecha_inicio', ascending: false);
      return (response as List).map((e) => VentanaModel.fromMap(e)).toList();
    } catch (e) {
      throw ServerException(message: 'Error al obtener historial');
    }
  }
}
