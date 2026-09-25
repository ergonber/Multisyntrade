import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/remote/supabase/supabase_client.dart';
import '../models/meta_model.dart';
import '../../../core/errors/app_exception.dart';

class MetasRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<MetaModel>> getMyMetas() async {
    try {
      final response = await _client
          .from('metas')
          .select()
          .order('created_at', ascending: false);
      return (response as List).map((e) => MetaModel.fromMap(e)).toList();
    } catch (e) {
      throw ServerException(message: 'Error al obtener metas');
    }
  }

  Future<MetaModel> createMeta({
    required String objetivo,
    required double montoMeta,
    String? descripcion,
    String? imagenUrl,
  }) async {
    try {
      final response = await _client
          .from('metas')
          .insert({
        'objetivo': objetivo,
        'monto_meta': montoMeta,
        'descripcion': descripcion,
        'imagen_url': imagenUrl,
      })
          .select()
          .single();
      return MetaModel.fromMap(response);
    } catch (e) {
      throw ServerException(message: 'Error al crear meta');
    }
  }

  Future<MetaModel> updateMeta(String metaId, Map<String, dynamic> data) async {
    try {
      final response = await _client
          .from('metas')
          .update(data)
          .eq('id', metaId)
          .select()
          .single();
      return MetaModel.fromMap(response);
    } catch (e) {
      throw ServerException(message: 'Error al actualizar meta');
    }
  }

  Future<void> deleteMeta(String metaId) async {
    try {
      await _client.from('metas').delete().eq('id', metaId);
    } catch (e) {
      throw ServerException(message: 'Error al eliminar meta');
    }
  }
}
