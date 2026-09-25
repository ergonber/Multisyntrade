import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/admin/admin_signals_repository.dart';
import '../../../data/models/ventana_model.dart';
import '../../../data/models/activo_model.dart';
import '../../../data/models/trade_execution_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminSignalsProvider extends ChangeNotifier {
  final AdminSignalsRepository _repo = AdminSignalsRepository();

  List<VentanaModel> _ventanas = [];
  List<ActivoModel> _activos = [];
  Map<String, TradeExecutionModel> _myExecutions = {};
  double _myCapital = 0;
  bool _isLoading = false;
  String? _error;

  List<VentanaModel> get ventanas => _ventanas;
  List<ActivoModel> get activos => _activos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get myCapital => _myCapital;

  TradeExecutionModel? getMyExecutionForVentana(String ventanaId) {
    return _myExecutions[ventanaId];
  }

  List<VentanaModel> get programadas => _ventanas.where((v) => v.isProgramada).toList();
  List<VentanaModel> get activas => _ventanas.where((v) => v.isActiva).toList();
  List<VentanaModel> get cerradas => _ventanas.where((v) => v.isCerrada).toList();
  List<VentanaModel> get canceladas => _ventanas.where((v) => v.isCancelada).toList();

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      final results = await Future.wait([
        _repo.getAllVentanas(),
        _repo.getActivos(),
        _repo.getMyExecutions(),
        if (userId != null)
          Supabase.instance.client.from('profiles').select('capital_inicial').eq('id', userId).single(),
      ]);
      _ventanas = results[0] as List<VentanaModel>;
      _activos = results[1] as List<ActivoModel>;
      _myExecutions = results[2] as Map<String, TradeExecutionModel>;
      if (results.length > 3 && results[3] is Map) {
        _myCapital = ((results[3] as Map)['capital_inicial'] ?? 0).toDouble();
      }
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error al cargar señales';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncActivos() async {
    try {
      await _repo.syncActivosFromDeriv();
      await load();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<String?> createVentana({
    required String activoId,
    required String derivSymbol,
    required String tipo,
    required String direccion,
    required DateTime fechaInicio,
    required double multiplicador,
    double? riesgoRecomendado,
  }) async {
    try {
      final id = await _repo.createVentana(
        activoId: activoId,
        derivSymbol: derivSymbol,
        tipo: tipo,
        direccion: direccion,
        fechaInicio: fechaInicio,
        multiplicador: multiplicador,
        riesgoRecomendado: riesgoRecomendado,
      );
      await load();
      return id;
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  /// Publish + fire-and-forget execution. Returns immediately.
  Future<String?> publishAndExecute(String ventanaId) async {
    try {
      await _repo.publishSignal(ventanaId);
      // Fire-and-forget: do NOT await execution result
      _repo.triggerExecution(ventanaId);
      await load();
      return ventanaId;
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> publish(String ventanaId) async {
    try {
      await _repo.publishSignal(ventanaId);
      await load();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  /// Close signal: instantly update DB state, then sell contracts in background.
  Future<bool> closeSignal(String ventanaId) async {
    try {
      // 1. Fast: close ventana state via RPC
      await _repo.closeVentanaState(ventanaId);
      // 2. Fire-and-forget: sell contracts via deriv-bridge
      _repo.triggerLiquidation(ventanaId);
      await load();
      return true;
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> cancel(String ventanaId) async {
    try {
      await _repo.cancelVentana(ventanaId);
      await load();
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
