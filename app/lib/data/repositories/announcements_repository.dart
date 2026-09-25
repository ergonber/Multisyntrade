import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/remote/supabase/supabase_client.dart';
import '../models/announcement_model.dart';
import '../../core/errors/app_exception.dart';

class AnnouncementsRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<AnnouncementModel>> getActiveAnnouncements() async {
    try {
      final response = await _client
          .from('announcements')
          .select()
          .eq('activo', true)
          .order('created_at', ascending: false);
      return (response as List).map((e) => AnnouncementModel.fromMap(e)).toList();
    } catch (e) {
      throw ServerException(message: 'Error al obtener anuncios');
    }
  }
}
