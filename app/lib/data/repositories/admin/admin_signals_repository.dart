import 'package:supabase_flutter/supabase_flutter.dart';
import '../../datasources/remote/supabase/supabase_client.dart';
import '../../models/ventana_model.dart';
import '../../models/activo_model.dart';
import '../../models/trade_execution_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminSignalsRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<VentanaModel>> getAllVentanas() async {
    try {
      final response = await _client
          .from('ventanas_senales')
          .select()
          .order('created_at', ascending: false);
      return (response as List)
          .map((e) => VentanaModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Error al obtener ventanas');
    }
  }

  Future<List<ActivoModel>> getActivos() async {
    try {
      final response = await _client
          .from('activos')
          .select()
          .eq('habilitado', true)
          .order('nombre');
      return (response as List)
          .map((e) => ActivoModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(message: 'Error al obtener activos');
    }
  }

  Future<String> createVentana({
    required String activoId,
    required String derivSymbol,
    required String tipo,
    required String direccion,
    required DateTime fechaInicio,
    required double multiplicador,
    double? riesgoRecomendado,
  }) async {
    try {
      final response = await _client.rpc('admin_create_ventana', params: {
        'p_activo_id': activoId,
        'p_deriv_symbol': derivSymbol,
        'p_tipo': tipo,
        'p_direccion': direccion,
        'p_fecha_inicio': fechaInicio.toIso8601String(),
        'p_multiplicador': multiplicador,
        'p_riesgo_recomendado': riesgoRecomendado,
      });
      return response as String;
    } catch (e) {
      throw ServerException(message: 'Error al crear ventana');
    }
  }

  Future<void> publishSignal(String ventanaId) async {
    try {
      await _client.rpc('admin_publish_signal', params: {
        'p_ventana_id': ventanaId,
      });
    } catch (e) {
      throw ServerException(message: 'Error al publicar señal');
    }
  }

  /// Fire-and-forget execution for a ventana via deriv-bridge.
  /// Returns immediately without waiting for the result.
  void triggerExecution(String ventanaId) {
    try {
      _client.functions.invoke(
        'deriv-bridge',
        body: {'action': 'execute', 'ventana_id': ventanaId},
      );
    } catch (_) {
      // Fire-and-forget: ignore errors
    }
  }

  /// Close ventana state instantly via RPC (fast).
  Future<void> closeVentanaState(String ventanaId) async {
    try {
      await _client.rpc('admin_close_ventana', params: {
        'p_ventana_id': ventanaId,
        'p_resultado': 'sin_operar',
      });
    } catch (e) {
      throw ServerException(message: 'Error al cerrar ventana');
    }
  }

  /// Fire-and-forget: sell contracts via deriv-bridge in background.
  void triggerLiquidation(String ventanaId) {
    try {
      _client.functions.invoke(
        'deriv-bridge',
        body: {'action': 'close', 'ventana_id': ventanaId},
      );
    } catch (_) {
      // Fire-and-forget: ignore errors
    }
  }

  Future<void> cancelVentana(String ventanaId) async {
    try {
      await _client.rpc('admin_cancel_ventana', params: {
        'p_ventana_id': ventanaId,
      });
    } catch (e) {
      throw ServerException(message: 'Error al cancelar ventana');
    }
  }

  Future<void> syncActivosFromDeriv() async {
    try {
      await _client.functions.invoke('deriv-sync-activos');
    } catch (e) {
      throw ServerException(message: 'Error al sincronizar activos');
    }
  }

  /// Fetch current user's executions keyed by ventana_id.
  Future<Map<String, TradeExecutionModel>> getMyExecutions() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return {};
      final response = await _client
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
}
