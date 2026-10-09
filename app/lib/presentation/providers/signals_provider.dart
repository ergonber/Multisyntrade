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

/// Señales propias (`ventanas_senales.origen = 'auto'`) + resultados
/// (`auto_trade_executions`), con realtime vía `.stream()`.
class SignalsProvider extends ChangeNotifier {
  final VentanasRepository _ventanasRepo = VentanasRepository();
  final ActivosRepository _activosRepo = ActivosRepository();

  static const Duration _staleAfter = Duration(seconds: 60);
  static const Duration _reconnectDelay = Duration(seconds: 5);

  final Map<String, VentanaModel> _ventanasById = {};
  List<ActivoModel> _activos = [];
  List<TradeExecutionModel> _executions = [];
  PerformanceModel? _performance;
  bool _isLoading = false;
  bool _fetching = false;
  String? _error;

  StreamSubscription<SupabaseStreamEvent>? _ventanasStream;
  StreamSubscription<SupabaseStreamEvent>? _executionsStream;
  Timer? _reconnectTimer;
  bool _realtimeStarting = false;
  bool _streamHealthy = false;
  String? _streamUserId;
  DateTime? _lastUpdatedAt;
  bool _disposed = false;

  List<ActivoModel> get activos => _activos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  PerformanceModel? get performance => _performance;

  /// true cuando los streams de realtime están vivos y recibiendo datos.
  bool get realtimeConnected => _streamHealthy;

  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  /// Sin datos frescos hace más de [_staleAfter].
  bool get isStale =>
      _lastUpdatedAt != null &&
      DateTime.now().difference(_lastUpdatedAt!) > _staleAfter;

  /// Nuestras señales (origen='auto'), de mayor a menor por apertura.
  List<VentanaModel> get liveSignals => _sorted(_ventanasById.values);

  List<VentanaModel> get activeVentanas =>
      liveSignals.where((v) => v.isActiva).toList();

  List<VentanaModel> get scheduledVentanas =>
      liveSignals.where((v) => v.isProgramada).toList();

  List<VentanaModel> get closedVentanas =>
      liveSignals.where((v) => v.isCerrada || v.isCancelada).toList();

  int get activeSignalCount => activeVentanas.length;

  DateTime? get lastSignalAt {
    DateTime? latest;
    for (final v in _ventanasById.values) {
      final t = v.senalAperturaDate ?? v.fechaInicio;
      if (latest == null || t.isAfter(latest)) latest = t;
    }
    return latest;
  }

  /// Resultados cerrados (ganada / perdida) de mis operaciones.
  List<TradeExecutionModel> get myResults => List.unmodifiable(
      _executions.where((e) => e.isGanada || e.isPerdida).toList());

  /// Operaciones abiertas (en curso / pendientes).
  List<TradeExecutionModel> get openExecutions => List.unmodifiable(
      _executions.where((e) => e.isEnCurso || e.estado == 'pendiente').toList());

  /// Últimas operaciones para el Home (cualquier estado, más recientes).
  List<TradeExecutionModel> get recentExecutions =>
      _executions.take(3).toList();

  int get openExecutionCount => openExecutions.length;

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
    for (final exec in _executions) {
      if (exec.ventanaId == ventanaId) return exec;
    }
    return null;
  }

  // ---------------------------------------------------------------
  // Realtime con supabase .stream()
  // ---------------------------------------------------------------

  Future<void> startRealtime() async {
    if (_disposed || _realtimeStarting) return;
    final client = SupabaseService.client;
    if (client.auth.currentSession == null) return;

    final userId = client.auth.currentUser?.id;

    // Si cambió el usuario logueado, recreamos los streams.
    if (_streamUserId != null && _streamUserId != userId) {
      _teardownStreams();
    }
    if (_ventanasStream != null && _executionsStream != null) return;

    _realtimeStarting = true;
    try {
      _ventanasStream ??= client
          .from('ventanas_senales')
          .stream(primaryKey: ['id'])
          .listen(
            _onVentanasStream,
            onError: (Object e) => _onStreamFailure('ventanas_senales', e),
            onDone: () => _onStreamFailure('ventanas_senales', 'closed'),
          );
      if (_executionsStream == null && userId != null) {
        _executionsStream = client
            .from('auto_trade_executions')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)
            .listen(
              _onExecutionsStream,
              onError: (Object e) =>
                  _onStreamFailure('auto_trade_executions', e),
              onDone: () =>
                  _onStreamFailure('auto_trade_executions', 'closed'),
            );
        _streamUserId = userId;
      }
    } finally {
      _realtimeStarting = false;
    }
  }

  void _onVentanasStream(SupabaseStreamEvent rows) {
    if (_disposed) return;
    _ventanasById.clear();
    for (final row in rows) {
      try {
        final ventana = VentanaModel.fromMap(row);
        if (ventana.id.isNotEmpty) _ventanasById[ventana.id] = ventana;
      } catch (_) {}
    }
    _markUpdated();
  }

  void _onExecutionsStream(SupabaseStreamEvent rows) {
    if (_disposed) return;
    final list = <TradeExecutionModel>[];
    for (final row in rows) {
      try {
        list.add(TradeExecutionModel.fromMap(row));
      } catch (_) {}
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _executions = list;
    _markUpdated();
  }

  void _markUpdated() {
    _lastUpdatedAt = DateTime.now();
    if (!_streamHealthy) _streamHealthy = true;
    notifyListeners();
  }

  void _onStreamFailure(String table, Object error) {
    if (_disposed) return;
    debugPrint('[Signals] stream $table: $error');
    _streamHealthy = false;
    _teardownStreams();
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_disposed) return;
      unawaited(startRealtime());
    });
  }

  void _teardownStreams() {
    final ventanas = _ventanasStream;
    final executions = _executionsStream;
    _ventanasStream = null;
    _executionsStream = null;
    _streamUserId = null;
    _streamHealthy = false;
    try {
      ventanas?.cancel();
    } catch (_) {}
    try {
      executions?.cancel();
    } catch (_) {}
  }

  void stopRealtime() {
    _reconnectTimer?.cancel();
    _teardownStreams();
    if (!_disposed) notifyListeners();
  }

  // ---------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------

  Future<void> fetchAll() async {
    if (_fetching || _disposed) return;
    _fetching = true;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _ventanasRepo.getAutoVentanas(),
        _activosRepo.getActivos(),
        _fetchMyExecutions(),
      ]);

      final ventanas = results[0] as List<VentanaModel>;
      _ventanasById
        ..clear()
        ..addEntries(ventanas.map((v) => MapEntry(v.id, v)));
      _activos = results[1] as List<ActivoModel>;
      _executions = results[2] as List<TradeExecutionModel>;
      _lastUpdatedAt = DateTime.now();
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error inesperado';
    } finally {
      _isLoading = false;
      _fetching = false;
      notifyListeners();
      unawaited(startRealtime());
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

      final list = [
        for (final e in response as List) TradeExecutionModel.fromMap(e)
      ];
      return list;
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
    _disposed = true;
    _reconnectTimer?.cancel();
    _teardownStreams();
    super.dispose();
  }
}
