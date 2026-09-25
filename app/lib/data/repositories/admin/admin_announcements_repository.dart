import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../datasources/remote/supabase/supabase_client.dart';
import '../../models/announcement_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminAnnouncementsRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<AnnouncementModel>> getAll() async {
    try {
      final response = await _client
          .from('announcements')
          .select()
          .order('creado_en', ascending: false);
      return (response as List)
          .map((e) => AnnouncementModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Error al obtener anuncios');
    }
  }

  Future<void> create({
    required String titulo,
    required String cuerpo,
    String? imageUrl,
    bool activo = true,
  }) async {
    try {
      await _client.from('announcements').insert({
        'titulo': titulo,
        'cuerpo': cuerpo,
        'image_url': imageUrl,
        'activo': activo,
      });
    } catch (e) {
      throw ServerException(message: 'Error al crear anuncio');
    }
  }

  Future<void> update({
    required String id,
    String? titulo,
    String? cuerpo,
    String? imageUrl,
    bool? activo,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (titulo != null) updates['titulo'] = titulo;
      if (cuerpo != null) updates['cuerpo'] = cuerpo;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (activo != null) updates['activo'] = activo;
      await _client.from('announcements').update(updates).eq('id', id);
    } catch (e) {
      throw ServerException(message: 'Error al actualizar anuncio');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('announcements').delete().eq('id', id);
    } catch (e) {
      throw ServerException(message: 'Error al eliminar anuncio');
    }
  }

  Future<String?> uploadImage(List<int> bytes, String fileName) async {
    try {
      await _client.storage.from('announcements').uploadBinary(fileName, Uint8List.fromList(bytes));
      return _client.storage.from('announcements').getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }
}
