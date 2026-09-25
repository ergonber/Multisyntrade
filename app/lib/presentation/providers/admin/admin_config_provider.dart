import 'package:flutter/material.dart';
import '../../../data/repositories/admin/admin_config_repository.dart';
import '../../../data/models/admin/app_config_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminConfigProvider extends ChangeNotifier {
  final AdminConfigRepository _repo = AdminConfigRepository();

  AppConfigModel _config = const AppConfigModel();
  bool _isLoading = false;
  String? _error;

  AppConfigModel get config => _config;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _config = await _repo.getConfig();
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error al cargar configuración';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleMaintenance(bool value) async {
    try {
      await _repo.updateConfig(maintenanceMode: value);
      _config = AppConfigModel(
        maintenanceMode: value,
        maintenanceMessage: _config.maintenanceMessage,
        appVersion: _config.appVersion,
      );
      notifyListeners();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> updateMessage(String? message) async {
    try {
      await _repo.updateConfig(maintenanceMessage: message);
      _config = AppConfigModel(
        maintenanceMode: _config.maintenanceMode,
        maintenanceMessage: message,
        appVersion: _config.appVersion,
      );
      notifyListeners();
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
