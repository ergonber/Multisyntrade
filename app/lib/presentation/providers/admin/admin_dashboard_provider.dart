import 'package:flutter/material.dart';
import '../../../data/repositories/admin/admin_dashboard_repository.dart';
import '../../../data/models/admin/admin_stats_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminDashboardProvider extends ChangeNotifier {
  final AdminDashboardRepository _repo = AdminDashboardRepository();

  AdminStatsModel _stats = const AdminStatsModel();
  List<Map<String, dynamic>> _expiringSubscriptions = [];
  List<Map<String, dynamic>> _recentActivity = [];
  bool _isLoading = false;
  String? _error;

  AdminStatsModel get stats => _stats;
  List<Map<String, dynamic>> get expiringSubscriptions => _expiringSubscriptions;
  List<Map<String, dynamic>> get recentActivity => _recentActivity;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repo.getStats(),
        _repo.getExpiringSubscriptions(),
        _repo.getRecentActivity(),
      ]);
      _stats = results[0] as AdminStatsModel;
      _expiringSubscriptions = results[1] as List<Map<String, dynamic>>;
      _recentActivity = results[2] as List<Map<String, dynamic>>;
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error al cargar dashboard';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
