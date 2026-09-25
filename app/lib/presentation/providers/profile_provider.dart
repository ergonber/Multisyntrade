import 'package:flutter/material.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/ventanas_repository.dart';
import '../../data/repositories/subscriptions_repository.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/user_stats_model.dart';
import '../../data/models/subscription_model.dart';
import '../../core/errors/app_exception.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileRepository _profileRepo = ProfileRepository();
  final VentanasRepository _ventanasRepo = VentanasRepository();
  final SubscriptionsRepository _subsRepo = SubscriptionsRepository();

  ProfileModel? _profile;
  UserStatsModel? _stats;
  SubscriptionModel? _subscription;
  bool _isLoading = false;
  String? _error;

  ProfileModel? get profile => _profile;
  UserStatsModel? get stats => _stats;
  SubscriptionModel? get subscription => _subscription;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadProfile(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _profileRepo.getProfile(userId),
        _subsRepo.getMyActiveSubscription(userId),
      ]);
      _profile = results[0] as ProfileModel?;
      _subscription = results[1] as SubscriptionModel?;
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error al cargar perfil';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    try {
      _profile = await _profileRepo.updateProfile(userId, data);
      notifyListeners();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> setCapital(String userId, double capital) async {
    try {
      await _profileRepo.setCapitalInicial(userId, capital);
      await loadProfile(userId);
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> setRisk(String userId, double risk) async {
    try {
      await _profileRepo.setRiskProfile(userId, risk);
      await loadProfile(userId);
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> updateNotificationPrefs(String userId, {
    bool? nuevaOperacion,
    bool? resultado,
    bool? promociones,
    bool? sistema,
    bool? objetivos,
  }) async {
    try {
      await _profileRepo.updateNotificationPrefs(
        userId,
        nuevaOperacion: nuevaOperacion,
        resultado: resultado,
        promociones: promociones,
        sistema: sistema,
        objetivos: objetivos,
      );
      await loadProfile(userId);
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
