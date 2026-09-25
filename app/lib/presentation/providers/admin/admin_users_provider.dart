import 'package:flutter/material.dart';
import '../../../data/repositories/admin/admin_users_repository.dart';
import '../../../data/models/admin/admin_user_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminUsersProvider extends ChangeNotifier {
  final AdminUsersRepository _repo = AdminUsersRepository();

  List<AdminUserModel> _users = [];
  bool _isLoading = false;
  String? _error;

  List<AdminUserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalUsers => _users.length;
  int get vipUsers => _users.where((u) => u.plan == 'vip' && u.isActive).length;
  int get freeUsers => totalUsers - vipUsers;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _users = await _repo.getAllUsers();
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error al cargar usuarios';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setRole(String userId, String role) async {
    try {
      await _repo.setRole(userId, role);
      await load();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> toggleStatus(String userId) async {
    try {
      await _repo.toggleStatus(userId);
      await load();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> setSubscription(String userId, String plan, {DateTime? fechaFin}) async {
    try {
      await _repo.setSubscription(userId, plan, fechaFin: fechaFin);
      await load();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<bool> activateSubscription(String userId, {int meses = 12}) async {
    try {
      await _repo.activateSubscription(userId, meses: meses);
      await load();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPayments(String userId) async {
    try {
      return await _repo.getUserPayments(userId);
    } catch (e) {
      return [];
    }
  }

  List<AdminUserModel> filter(String query) {
    if (query.isEmpty) return _users;
    final q = query.toLowerCase();
    return _users.where((u) =>
      u.nombre.toLowerCase().contains(q) ||
      (u.email?.toLowerCase().contains(q) ?? false) ||
      (u.telefono?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
