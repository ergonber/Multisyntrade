import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  final Map<String, VentanaModel> _ventanasById = {};
  List<ActivoModel> _activos = [];
  List<TradeExecutionModel> _myResults = [];
  Map<String, TradeExecutionModel> _myExecutions = {};
  PerformanceModel? _performance;
  bool _isLoading = false;
  String? _error;

  RealtimeChannel? _channel;
  bool _realtimeConnected = false;
  bool _realtimeStarting = false;
  Timer? _execRefreshTimer;

  List<ActivoModel> get activos => _activos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  PerformanceModel? get performance => _performance;
  bool get realtimeConnected => _realtimeConnected;

  List<VentanaModel> get liveSignals => _sorted(_ventanasById.values);

  List<VentanaModel> get activeVentanas =>
      liveSignals.where((v) => v.isActiva).toList();

  List<VentanaModel> get scheduledVentanas =>
      liveSignals.where((v) => v.isProgramada).toList();

  List<VentanaModel> get closedVentanas =>
      liveSignals.where((v) => v.isCerrada || v.isCancelada).toList();

  int get activeSignalCount => _ventanasById.values.where((v) => v.isActiva).length;

  DateTime? get lastSignalAt {
    DateTime? latest;
    for (final v in _ventanasById.values) {
      final t = v.senalAperturaDate ?? v.fechaInicio;
      if (latest == null || t.isAfter(latest)) latest = t;
    }
    return latest;
  }

  List<TradeExecutionModel> get myResults => List.unmodifiable(_myResults);

  List<TradeExecutionModel> get recentExecutions =>
      _myResults.take(3).toList();

  static int _bySenalDesc(VentanaModel a, VentanaModel b) {
    final da = a.senalAperturaDate ?? a.fechaInicio;
    final db = b.senalAperturaDate ?? b.fechaInicio;
    final c = db.compareTo(da);
    if (c != 0) return c;
    return b.createdAt.compareTo(a.createdAt);
  }

  static List<VentanaModel> _sorted(Iterable<VentanaModel> values) {
    final list = values.toList()..sort(_bySenalDesc);
    return list;
  }

  TradeExecutionModel? getExecutionForVentana(String ventanaId) {
    return _myExecutions[ventanaId];
  }

  // ---------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------

  Future<void> startRealtime() async {
    if (_channel != null || _realtimeStarting) return;
    final client = SupabaseService.client;
    if (client.auth.currentSession == null) return;

    _realtimeStarting = true;
    try {
      _channel = client
          .channel('ventanas_senales_live')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'ventanas_senales',
            callback: _onRemoteChange,
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'ventanas_senales',
            callback: _onRemoteChange,
          )
          .subscribe(_onSubscribeStatus);
    } finally {
      _realtimeStarting = false;
    }
  }

  void _onSubscribeStatus(RealtimeSubscribeStatus status, Object? error) {
    final wasConnected = _realtimeConnected;
    _realtimeConnected = status == RealtimeSubscribeStatus.subscribed;
    if (error != null) {
      debugPrint('[Signals] realtime $status: $error');
    }
    if (wasConnected != _realtimeConnected) notifyListeners();
  }

  void _onRemoteChange(PostgresChangePayload payload) {
    final record = payload.newRecord;
    if (record.isEmpty) return;

    final incoming = VentanaModel.fromMap(record);
    if (incoming.id.isEmpty) return;

    final previous = _ventanasById[incoming.id];
    _ventanasById[incoming.id] = incoming;
    notifyListeners();

    final changed = previous == null ||
        previous.estado != incoming.estado ||
        previous.resultado != incoming.resultado;
    if (changed) _scheduleResultsRefresh();
  }

  void _scheduleResultsRefresh() {
    _execRefreshTimer?.cancel();
    _execRefreshTimer = Timer(const Duration(milliseconds: 600), () {
      _fetchMyExecutions().then((results) {
        _myResults = results;
        _myExecutions = _indexByVentana(results);
        notifyListeners();
      });
    });
  }

  void stopRealtime() {
    _execRefreshTimer?.cancel();
    final channel = _channel;
    _channel = null;
    _realtimeConnected = false;
    try {
      channel?.unsubscribe();
    } catch (_) {}
  }

  // ---------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------

  Future<void> fetchAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _ventanasRepo.getAllVentanas(),
        _activosRepo.getActivos(),
        _fetchMyExecutions(),
      ]);

      final ventanas = results[0] as List<VentanaModel>;
      _ventanasById
        ..clear()
        ..addEntries(ventanas.map((v) => MapEntry(v.id, v)));
      _activos = results[1] as List<ActivoModel>;
      _myResults = results[2] as List<TradeExecutionModel>;
      _myExecutions = _indexByVentana(_myResults);
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error inesperado';
    } finally {
      _isLoading = false;
      notifyListeners();
      unawaited(startRealtime());
    }
  }

  static Map<String, TradeExecutionModel> _indexByVentana(
      List<TradeExecutionModel> results) {
    final map = <String, TradeExecutionModel>{};
    for (final exec in results) {
      if (!map.containsKey(exec.ventanaId)) {
        map[exec.ventanaId] = exec;
      }
    }
    return map;
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

  Future<List<TradeExecutionModel>> _fetchMyExecutions() async {
    try {
      final client = SupabaseService.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await client
          .from('auto_trade_executions')
          .select()
          .eq('user_id', userId)
          .order('creado_en', ascending: false);

      return [
        for (final e in response as List) TradeExecutionModel.fromMap(e)
      ];
    } catch (_) {
      return [];
    }
  }

  VentanaModel? getVentanaById(String id) => _ventanasById[id];

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _execRefreshTimer?.cancel();
    final channel = _channel;
    _channel = null;
    try {
      channel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }
}
