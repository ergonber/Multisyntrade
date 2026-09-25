import 'package:flutter/material.dart';
import '../../data/datasources/remote/supabase/supabase_client.dart';
import '../../data/repositories/ventanas_repository.dart';
import '../../data/repositories/activos_repository.dart';
import '../../data/models/ventana_model.dart';
import '../../data/models/activo_model.dart';
import '../../data/models/trade_execution_model.dart';
import '../../data/models/user_stats_model.dart';
import '../../core/errors/app_exception.dart';

class SignalsProvider extends ChangeNotifier {
  final VentanasRepository _ventanasRepo = VentanasRepository();
  final ActivosRepository _activosRepo = ActivosRepository();

  List<VentanaModel> _activeVentanas = [];
  List<VentanaModel> _scheduledVentanas = [];
  List<VentanaModel> _closedVentanas = [];
  List<ActivoModel> _activos = [];
  Map<String, TradeExecutionModel> _myExecutions = {};
  PerformanceModel? _performance;
  bool _isLoading = false;
  String? _error;

  List<VentanaModel> get activeVentanas => _activeVentanas;
  List<VentanaModel> get scheduledVentanas => _scheduledVentanas;
  List<VentanaModel> get closedVentanas => _closedVentanas;
  List<ActivoModel> get activos => _activos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  PerformanceModel? get performance => _performance;

  List<TradeExecutionModel> get recentExecutions {
    final all = _myExecutions.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(3).toList();
  }

  TradeExecutionModel? getExecutionForVentana(String ventanaId) {
    return _myExecutions[ventanaId];
  }

  Future<void> fetchAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _ventanasRepo.getActiveVentanas(),
        _ventanasRepo.getScheduledVentanas(),
        _ventanasRepo.getClosedVentanas(),
        _activosRepo.getActivos(),
        _fetchMyExecutions(),
      ]);
      _activeVentanas = results[0] as List<VentanaModel>;
      _scheduledVentanas = results[1] as List<VentanaModel>;
      _closedVentanas = results[2] as List<VentanaModel>;
      _activos = results[3] as List<ActivoModel>;
      _myExecutions = results[4] as Map<String, TradeExecutionModel>;
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error inesperado';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPerformance({String period = 'all'}) async {
    try {
      final client = SupabaseService.client;
      final response = await client.rpc('get_user_performance', params: {
        'p_period': period,
      });
      if (response is List && response.isNotEmpty) {
        _performance = PerformanceModel.fromMap(response[0]);
      } else {
        _performance = const PerformanceModel();
      }
      notifyListeners();
    } catch (_) {
      _performance = const PerformanceModel();
      notifyListeners();
    }
  }

  Future<Map<String, TradeExecutionModel>> _fetchMyExecutions() async {
    try {
      final client = SupabaseService.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return {};

      final response = await client
          .from('auto_trade_executions')
          .select()
          .eq('user_id', userId)
          .order('creado_en', ascending: false);

      final map = <String, TradeExecutionModel>{};
      for (final e in response as List) {
        final exec = TradeExecutionModel.fromMap(e);
        if (!map.containsKey(exec.ventanaId)) {
          map[exec.ventanaId] = exec;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  VentanaModel? getVentanaById(String id) {
    try {
      return _activeVentanas.firstWhere((v) => v.id == id);
    } catch (_) {
      try {
        return _scheduledVentanas.firstWhere((v) => v.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
