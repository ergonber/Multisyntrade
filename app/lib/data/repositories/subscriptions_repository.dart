import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/remote/supabase/supabase_client.dart';
import '../models/subscription_model.dart';
import '../../../core/errors/app_exception.dart';

class SubscriptionsRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<SubscriptionModel?> getMySubscription(String userId) async {
    try {
      final response = await _client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .order('fecha_inicio', ascending: false)
          .maybeSingle();
      if (response == null) return null;
      return SubscriptionModel.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<SubscriptionModel?> getMyActiveSubscription(String userId) async {
    try {
      final response = await _client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('estado', 'activa')
          .order('fecha_inicio', ascending: false)
          .maybeSingle();
      if (response == null) return null;
      return SubscriptionModel.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<List<SubscriptionModel>> getMySubscriptions(String userId) async {
    try {
      final response = await _client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .order('fecha_inicio', ascending: false);
      return (response as List).map((e) => SubscriptionModel.fromMap(e)).toList();
    } catch (e) {
      throw ServerException(message: 'Error al obtener suscripciones');
    }
  }

  Future<bool> hasActiveSubscription(String userId) async {
    final sub = await getMyActiveSubscription(userId);
    return sub?.isActive ?? false;
  }
}
