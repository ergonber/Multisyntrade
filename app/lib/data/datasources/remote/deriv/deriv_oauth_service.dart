import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/app_exception.dart';
import '../supabase/supabase_client.dart';

/// Service for reading Deriv connection status from Supabase.
/// Token exchange and encryption happen server-side in Edge Functions.
class DerivOAuthService {
  static final DerivOAuthService _instance = DerivOAuthService._();
  factory DerivOAuthService() => _instance;
  DerivOAuthService._();

  final SupabaseClient _client = SupabaseService.client;

  /// Get stored access token (with auto-refresh if expired)
  Future<String?> getAccessToken() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('deriv_connections')
          .select('ciphertext, expires_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      final expiresAt = response['expires_at'] as String?;
      if (expiresAt != null) {
        final expiry = DateTime.parse(expiresAt).toUtc();
        if (DateTime.now().toUtc().isAfter(expiry)) {
          debugPrint('[DerivOAuth] Token expired');
          return null;
        }
      }

      return response['ciphertext'];
    } catch (e) {
      return null;
    }
  }

  /// Get stored account ID
  Future<String?> getAccountId() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('deriv_connections')
          .select('loginid')
          .eq('user_id', userId)
          .maybeSingle();

      return response?['loginid'];
    } catch (e) {
      return null;
    }
  }

  /// Check if connected
  Future<bool> isConnected() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _client
          .from('deriv_connections')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Disconnect (client-side only - server handles cleanup via RPC)
  Future<void> disconnect() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        await _client.rpc('disconnect_deriv');
      }
    } catch (e) {
      throw DerivAuthException(message: 'Error disconnecting');
    }
  }
}
