import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/repositories/admin/admin_signals_repository.dart';
import '../../../data/models/ventana_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminSignalsProvider extends ChangeNotifier {
  final AdminSignalsRepository _repo = AdminSignalsRepository();

  List<VentanaModel> _ventanas = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;

  List<VentanaModel> get ventanas => _ventanas;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<VentanaModel> get activas => _ventanas.where((v) => v.isActiva).toList();
  List<VentanaModel> get cerradas => _ventanas.where((v) => v.isCerrada).toList();
  List<VentanaModel> get programadas => _ventanas.where((v) => v.isProgramada).toList();
  List<VentanaModel> get canceladas => _ventanas.where((v) => v.isCancelada).toList();

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _ventanas = await _repo.getAllVentanas();
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error al cargar señales';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Suscripción Realtime a las ventanas que llegan del MT5 (solo lectura).
  void subscribeRealtime() {
    if (_realtimeSub != null) return;
    try {
      _realtimeSub = _repo
          .streamVentanas()
          .listen((rows) {
            _ventanas = rows.map((e) => VentanaModel.fromMap(e)).toList();
            _isLoading = false;
            notifyListeners();
          }, onError: (_) {
            _error = 'Error en la conexión en tiempo real';
            notifyListeners();
          });
    } catch (_) {
      _error = 'Error al conectar en tiempo real';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }
}
