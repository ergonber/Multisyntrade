import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/trade_execution_model.dart';
import '../../../data/models/ventana_model.dart';
import '../../providers/signals_provider.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());

    // Realtime es la fuente principal; este timer solo entra si la
    // suscripción no llegó a conectarse.
    _fallbackTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      final provider = context.read<SignalsProvider>();
      if (!provider.realtimeConnected && !provider.isLoading) {
        provider.fetchAll();
      }
    });
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final provider = context.read<SignalsProvider>();
    await provider.fetchAll();
    if (mounted) await provider.startRealtime();
  }

  Future<void> _refresh() => context.read<SignalsProvider>().fetchAll();

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signals = context.watch<SignalsProvider>();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Señales',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Señales en vivo y tus resultados',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 16),
                _LiveCounter(provider: signals),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: 'Señales en vivo'),
                      Tab(text: 'Mis resultados'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (signals.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(signals.error!,
                  style: const TextStyle(color: AppColors.negative, fontSize: 12)),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLiveList(signals),
                _buildResultsList(signals),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Señales en vivo (public.ventanas_senales)
  // ------------------------------------------------------------------

  Widget _buildLiveList(SignalsProvider provider) {
    final signals = provider.liveSignals;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: signals.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text('No hay señales todavía',
                      style: TextStyle(color: Colors.grey)),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: signals.length,
              itemBuilder: (context, index) =>
                  _SignalRow(ventana: signals[index]),
            ),
    );
  }

  // ------------------------------------------------------------------
  // Mis resultados (public.auto_trade_executions)
  // ------------------------------------------------------------------

  Widget _buildResultsList(SignalsProvider provider) {
    final results = provider.myResults;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: results.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text('Todavía no tenés operaciones',
                      style: TextStyle(color: Colors.grey)),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: results.length,
              itemBuilder: (context, index) =>
                  _ResultRow(execution: results[index]),
            ),
    );
  }
}

// ======================================================================
// Contador de señales activas + "última hace Xs"
// ======================================================================

class _LiveCounter extends StatefulWidget {
  const _LiveCounter({required this.provider});

  final SignalsProvider provider;

  @override
  State<_LiveCounter> createState() => _LiveCounterState();
}

class _LiveCounterState extends State<_LiveCounter> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _elapsed(DateTime? from) {
    if (from == null) return '—';
    var diff = DateTime.now().difference(from);
    if (diff.isNegative) diff = Duration.zero;
    if (diff.inSeconds < 60) return 'hace ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    return Formatters.dateOnly(from);
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final connected = provider.realtimeConnected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: connected ? AppColors.positive : AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${provider.activeSignalCount} señales activas',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Text(
            'Última ${_elapsed(provider.lastSignalAt)}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Fila de señal en vivo
// ======================================================================

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.ventana});

  final VentanaModel ventana;

  Color get _directionColor =>
      ventana.isCompra ? AppColors.positive : AppColors.negative;

  @override
  Widget build(BuildContext context) {
    final color = _directionColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    ventana.isCompra
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ventana.derivSymbol,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(ventana.directionLabel,
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    Formatters.dateTime(ventana.sortDate),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusDot(
                  color: ventana.isActiva
                      ? AppColors.warning
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  ventana.isActiva ? 'Activa' : 'Cerrada',
                  style: const TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                if (ventana.resultado != null)
                  _ResultLabel(resultado: ventana.resultado!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Fila de resultado propio
// ======================================================================

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.execution});

  final TradeExecutionModel execution;

  String get _estadoLabel {
    switch (execution.estado) {
      case 'en_curso':
        return 'En curso';
      case 'ganada':
        return 'Ganada';
      case 'perdida':
        return 'Perdida';
      case 'pendiente':
        return 'Pendiente';
      case 'rechazada':
        return 'Rechazada';
      case 'cancelada':
        return 'Cancelada';
      default:
        return execution.estado;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = execution.isGanada
        ? AppColors.positive
        : execution.isPerdida
            ? AppColors.negative
            : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                execution.isGanada
                    ? Icons.arrow_upward
                    : execution.isPerdida
                        ? Icons.arrow_downward
                        : Icons.hourglass_top,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(execution.derivSymbol,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    'Monto ${Formatters.currency(execution.monto)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ProfitBadge(execution: execution),
                const SizedBox(height: 6),
                Text(
                  _estadoLabel,
                  style: TextStyle(color: color, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.dateTime(execution.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Piezas compartidas
// ======================================================================

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _ResultLabel extends StatelessWidget {
  const _ResultLabel({required this.resultado});

  final String resultado;

  @override
  Widget build(BuildContext context) {
    final color = resultado == 'ganada'
        ? AppColors.positive
        : resultado == 'perdida'
            ? AppColors.negative
            : AppColors.textSecondary;

    final label = resultado == 'ganada'
        ? 'Ganada'
        : resultado == 'perdida'
            ? 'Perdida'
            : 'Sin operar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }
}

class _ProfitBadge extends StatelessWidget {
  const _ProfitBadge({required this.execution});

  final TradeExecutionModel execution;

  @override
  Widget build(BuildContext context) {
    final value = execution.resultado;
    if (value == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('—',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    final color = value >= 0 ? AppColors.positive : AppColors.negative;
    final sign = value > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$sign\$${value.toStringAsFixed(2)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}
