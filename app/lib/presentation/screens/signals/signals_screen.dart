import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../providers/signals_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../data/models/trade_execution_model.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        context.read<SignalsProvider>().fetchAll();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Señales',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Gestiona tus operaciones de trading',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                      Tab(text: 'Activas'),
                      Tab(text: 'Programadas'),
                      Tab(text: 'Historial'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (signals.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(signals.error!,
                  style: const TextStyle(color: AppColors.negative, fontSize: 12)),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSignalList(signals.activeVentanas, signals),
                _buildSignalList(signals.scheduledVentanas, signals),
                _buildSignalList(signals.closedVentanas, signals, isHistory: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalList(
    List signals,
    SignalsProvider provider, {
    bool isHistory = false,
  }) {
    if (signals.isEmpty) {
      return const Center(
        child: Text('No hay señales', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: signals.length,
      itemBuilder: (context, index) {
        final ventana = signals[index];
        final color = ventana.isCompra ? AppColors.positive : AppColors.negative;

        final execution = provider.getExecutionForVentana(ventana.id);
        final hasExecution = execution != null && execution.estado != 'cancelada';
        final hasResult = hasExecution && execution.resultado != null;

        String estadoLabel;
        Color estadoColor;
        if (hasExecution) {
          if (execution.isGanada) {
            estadoLabel = 'Ganada';
            estadoColor = AppColors.positive;
          } else if (execution.isPerdida) {
            estadoLabel = 'Perdida';
            estadoColor = AppColors.negative;
          } else {
            estadoLabel = execution.estado.toUpperCase();
            estadoColor = AppColors.warning;
          }
        } else {
          estadoLabel = ventana.estadoLabel;
          estadoColor = color;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Column(
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
                        ventana.isCompra ? Icons.trending_up : Icons.trending_down,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ventana.derivSymbol,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(ventana.directionLabel,
                              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    if (ventana.multiplicador != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('x${ventana.multiplicador!.toInt()}',
                            style: const TextStyle(
                                color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: estadoColor, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(estadoLabel,
                            style: TextStyle(color: estadoColor, fontWeight: FontWeight.w500)),
                        if (isHistory && hasResult) ...[
                          const SizedBox(width: 10),
                          _buildResultBadge(execution),
                        ],
                      ],
                    ),
                    Text(ventana.fechaInicio.toString().substring(0, 16),
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                if (isHistory && hasExecution && !hasResult)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text('Sin resultado registrado',
                            style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultBadge(TradeExecutionModel execution) {
    final isPositive = execution.isPositive;
    final sign = isPositive ? '+' : '';
    final color = isPositive ? AppColors.positive : AppColors.negative;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$sign\$${execution.resultado!.toStringAsFixed(2)}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
