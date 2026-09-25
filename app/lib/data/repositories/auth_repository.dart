import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/remote/supabase/supabase_client.dart';
import '../models/profile_model.dart';
import '../../config/app_config.dart';
import '../../core/errors/app_exception.dart' as app;

class AuthRepository {
  final SupabaseClient _client = SupabaseService.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  bool get isAuthenticated => currentSession != null;

  String get _redirectTo => AppConfig.appUrl;

  String _mapSupabaseError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('user already registered') || lower.contains('already registered')) {
      return 'Ya existe una cuenta con ese correo.';
    }
    if (lower.contains('invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Debes confirmar tu correo.';
    }
    if (lower.contains('over_email_send_rate_limit') || lower.contains('rate limit')) {
      return 'Demasiados intentos, esperá un momento.';
    }
    if (lower.contains('password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (lower.contains('unable to validate email address')) {
      return 'Correo electrónico inválido.';
    }
    return message;
  }

  Future<AuthResponse> signIn(String email, String password) async {
    try {
      return await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw app.AuthException(message: _mapSupabaseError(e.message));
    } catch (e) {
      throw app.AuthException(message: 'Error al iniciar sesión');
    }
  }

  Future<AuthResponse> signUp(String name, String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'nombre': name},
        emailRedirectTo: _redirectTo,
      );
      return response;
    } on AuthException catch (e) {
      throw app.AuthException(message: _mapSupabaseError(e.message));
    } catch (e) {
      throw app.AuthException(message: 'Error al crear cuenta');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw app.AuthException(message: 'Error al cerrar sesión');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email, redirectTo: _redirectTo);
    } on AuthException catch (e) {
      throw app.AuthException(message: _mapSupabaseError(e.message));
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw app.AuthException(message: _mapSupabaseError(e.message));
    }
  }

  Future<ProfileModel?> getCurrentProfile() async {
    if (currentUser == null) return null;
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .maybeSingle();
      if (response == null) return null;
      return ProfileModel.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
}
