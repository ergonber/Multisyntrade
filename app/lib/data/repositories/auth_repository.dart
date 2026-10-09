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

  String get _recoveryRedirect => AppConfig.recoveryRedirectUrl;

  /// Mensaje real de Supabase, sin el prefijo de la excepción.
  static String _rawMessage(Object error) {
    var text = error.toString();
    const prefixes = ['Exception: ', 'AuthException: ', 'FormatException: '];
    for (final p in prefixes) {
      if (text.startsWith(p)) {
        text = text.substring(p.length);
        break;
      }
    }
    return text.trim();
  }

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
      throw app.AuthException(message: _mapSupabaseError(_rawMessage(e)));
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
      // Supabase devuelve un usuario sin identidades cuando la cuenta ya existe
      // (en lugar de lanzar un error).
      final identities = response.user?.identities;
      if (response.user != null && identities != null && identities.isEmpty) {
        throw const app.AuthException(
            message: 'Ya existe una cuenta con ese correo.');
      }
      return response;
    } on app.AuthException {
      rethrow;
    } on AuthException catch (e) {
      throw app.AuthException(message: _mapSupabaseError(e.message));
    } catch (e) {
      throw app.AuthException(message: _mapSupabaseError(_rawMessage(e)));
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
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: _recoveryRedirect,
      );
    } on AuthException catch (e) {
      throw app.AuthException(message: _mapSupabaseError(e.message));
    } catch (e) {
      throw app.AuthException(message: _mapSupabaseError(_rawMessage(e)));
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw app.AuthException(message: _mapSupabaseError(e.message));
    } catch (e) {
      throw app.AuthException(message: _mapSupabaseError(_rawMessage(e)));
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
