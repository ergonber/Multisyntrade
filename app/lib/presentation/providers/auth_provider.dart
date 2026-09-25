import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/subscriptions_repository.dart';
import '../../data/models/profile_model.dart';
import '../../services/device_service.dart';
import '../../core/errors/app_exception.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepo = AuthRepository();
  final ProfileRepository _profileRepo = ProfileRepository();
  final SubscriptionsRepository _subRepo = SubscriptionsRepository();

  AuthStatus _status = AuthStatus.initial;
  ProfileModel? _profile;
  String? _subscriptionEstado;
  String? _subscriptionPlan;
  DateTime? _subscriptionFechaFin;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;
  String? _deviceMismatchMessage;

  AuthStatus get status => _status;
  ProfileModel? get profile => _profile;
  String? get subscriptionEstado => _subscriptionEstado;
  String? get subscriptionPlan => _subscriptionPlan;
  DateTime? get subscriptionFechaFin => _subscriptionFechaFin;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isAdmin => _profile?.isAdmin ?? false;
  User? get currentUser => _authRepo.currentUser;
  String get userName => _profile?.nombre ?? currentUser?.userMetadata?['nombre'] ?? currentUser?.userMetadata?['name'] ?? 'Trader';
  String get userEmail => currentUser?.email ?? '';
  String? get deviceMismatchMessage => _deviceMismatchMessage;

  bool get hasAccess {
    if (!isAuthenticated) return false;
    if (isAdmin) return true;
    if (_subscriptionEstado == null) return false;
    if (_subscriptionEstado == 'activa' &&
        _subscriptionFechaFin != null &&
        _subscriptionFechaFin!.isAfter(DateTime.now())) {
      return true;
    }
    return false;
  }

  bool get isPending => _subscriptionEstado == 'pendiente';
  bool get isExpired => _subscriptionEstado == 'activa' &&
      _subscriptionFechaFin != null &&
      _subscriptionFechaFin!.isBefore(DateTime.now());
  bool get isCancelled => _subscriptionEstado == 'cancelada';
  bool get isBlocked => isAuthenticated && !hasAccess && !isAdmin;

  void init() {
    _authSubscription = _authRepo.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _loadProfile();
      } else {
        _status = AuthStatus.unauthenticated;
        _profile = null;
        _subscriptionEstado = null;
        _subscriptionPlan = null;
        _subscriptionFechaFin = null;
        notifyListeners();
      }
    });

    if (_authRepo.isAuthenticated) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      _profile = await _authRepo.getCurrentProfile();
      _status = AuthStatus.authenticated;
    } catch (e) {
      _status = AuthStatus.authenticated;
      _profile = null;
    }

    // Cargar suscripción
    await _loadSubscription();

    // Verificar dispositivo (solo en restore; el registro se hace al iniciar sesión)
    await _verifyDevice();

    notifyListeners();
  }

  Future<void> _verifyDevice() async {
    if (kIsWeb || _profile == null) return;

    final stored = _profile!.deviceId;
    if (stored == null || stored.isEmpty) return; // aún no hay dispositivo registrado

    final isMatch = await DeviceService.isCurrentDevice(stored);
    if (!isMatch) {
      _deviceMismatchMessage = 'Tu cuenta se inició en otro dispositivo.';
      await signOut();
    }
  }

  Future<void> checkDeviceOnResume() async {
    if (kIsWeb || !isAuthenticated || _profile == null) return;

    // Recargar perfil para obtener device_id actual
    try {
      final freshProfile = await _authRepo.getCurrentProfile();
      if (freshProfile != null) {
        final isMatch = await DeviceService.isCurrentDevice(freshProfile.deviceId);
        if (!isMatch && freshProfile.deviceId != null && freshProfile.deviceId!.isNotEmpty) {
          _deviceMismatchMessage = 'Tu cuenta se inició en otro dispositivo.';
          await signOut();
        }
      }
    } catch (e) {
      // Non-critical
    }
  }

  Future<void> _loadSubscription() async {
    if (currentUser == null) return;
    try {
      final sub = await _subRepo.getMySubscription(currentUser!.id);
      if (sub != null) {
        _subscriptionEstado = sub.estado;
        _subscriptionPlan = sub.plan;
        _subscriptionFechaFin = sub.fechaFin;
      } else {
        _subscriptionEstado = null;
        _subscriptionPlan = null;
        _subscriptionFechaFin = null;
      }
    } catch (e) {
      _subscriptionEstado = null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    _error = null;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authRepo.signIn(email, password);
      await DeviceService.registerDevice();
      await _loadProfile();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    _error = null;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final response = await _authRepo.signUp(name, email, password);
      if (response.session != null) {
        await DeviceService.registerDevice();
        await _loadProfile();
      } else {
        // Sin sesión (p. ej. confirmación requerida): no autenticado.
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      }
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authRepo.signOut();
    _profile = null;
    _subscriptionEstado = null;
    _subscriptionPlan = null;
    _subscriptionFechaFin = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    await _loadProfile();
  }

  Future<void> updatePassword(String newPassword) async {
    await _authRepo.updatePassword(newPassword);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
