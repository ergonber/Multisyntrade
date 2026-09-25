import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../providers/admin/admin_dashboard_provider.dart';
import '../widgets/admin_stat_card.dart';
import '../widgets/admin_section_title.dart';
import '../widgets/admin_empty_state.dart';
import '../widgets/admin_loading.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminDashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminDashboardProvider>();

    return SafeArea(
      child: provider.isLoading
          ? const AdminLoading(message: 'Cargando dashboard...')
          : provider.error != null
              ? AdminEmptyState(
                  icon: Icons.error_outline,
                  title: 'Error',
                  subtitle: provider.error,
                  actionLabel: 'Reintentar',
                  onAction: () => provider.load(),
                )
              : RefreshIndicator(
                  onRefresh: () => provider.load(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Admin Dashboard',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        _buildStats(provider),
                        const SizedBox(height: 24),
                        const AdminSectionTitle(title: 'PRÓXIMOS VENCIMIENTOS'),
                        const SizedBox(height: 12),
                        _buildExpiringSubscriptions(provider),
                        const SizedBox(height: 24),
                        const AdminSectionTitle(title: 'ACTIVIDAD RECIENTE'),
                        const SizedBox(height: 12),
                        _buildRecentActivity(provider),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStats(AdminDashboardProvider provider) {
    final stats = provider.stats;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: AdminStatCard(label: 'USUARIOS', value: '${stats.totalUsers}', icon: Icons.people)),
            const SizedBox(width: 12),
            Expanded(child: AdminStatCard(label: 'SEÑALES HOY', value: '${stats.signalsToday}', icon: Icons.show_chart)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: AdminStatCard(label: 'SUSCRIPCIONES', value: '${stats.activeSubscriptions}', icon: Icons.star)),
            const SizedBox(width: 12),
            Expanded(
              child: AdminStatCard(
                label: 'EFFECTIVIDAD',
                value: '${stats.effectiveness.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
                valueColor: stats.effectiveness >= 50 ? AppColors.positive : AppColors.negative,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: AdminStatCard(label: 'VIP', value: '${stats.vipUsers}', icon: Icons.diamond, valueColor: AppColors.warning)),
            const SizedBox(width: 12),
            Expanded(child: AdminStatCard(label: 'FREE', value: '${stats.freeUsers}', icon: Icons.person_outline)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: AdminStatCard(label: 'GANADAS', value: '${stats.wonSignals}', valueColor: AppColors.positive)),
            const SizedBox(width: 12),
            Expanded(child: AdminStatCard(label: 'PERDIDAS', value: '${stats.lostSignals}', valueColor: AppColors.negative)),
          ],
        ),
      ],
    );
  }

  Widget _buildExpiringSubscriptions(AdminDashboardProvider provider) {
    if (provider.expiringSubscriptions.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.event_available,
        title: 'Sin vencimientos próximos',
        subtitle: 'No hay suscripciones que venzan en 3 días',
      );
    }
    return Column(
      children: provider.expiringSubscriptions.take(5).map((sub) {
        final user = sub['profiles'] as Map<String, dynamic>?;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(Icons.person, color: AppColors.warning, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?['nombre'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('Plan: ${sub['plan'] ?? '-'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                sub['fecha_fin'] != null ? _formatDate(sub['fecha_fin']) : '-',
                style: const TextStyle(color: AppColors.warning, fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentActivity(AdminDashboardProvider provider) {
    if (provider.recentActivity.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.history,
        title: 'Sin actividad reciente',
      );
    }
    return Column(
      children: provider.recentActivity.take(5).map((activity) {
        final estado = activity['estado'] ?? '';
        final resultado = activity['resultado'];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(
                estado == 'activa' ? Icons.radio_button_checked :
                estado == 'cerrada' ? Icons.check_circle : Icons.schedule,
                color: estado == 'activa' ? AppColors.positive :
                       resultado == 'ganada' ? AppColors.positive :
                       resultado == 'perdida' ? AppColors.negative : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activity['titulo'] ?? activity['deriv_symbol'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('${activity['deriv_symbol'] ?? ''} - $estado',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              if (activity['created_at'] != null)
                Text(_formatDate(activity['created_at']),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
