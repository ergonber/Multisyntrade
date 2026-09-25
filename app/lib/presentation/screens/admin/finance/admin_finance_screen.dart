import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../providers/admin/admin_finance_provider.dart';
import '../widgets/admin_stat_card.dart';
import '../widgets/admin_section_title.dart';
import '../widgets/admin_empty_state.dart';
import '../widgets/admin_loading.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminFinanceProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminFinanceProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Finanzas')),
      body: provider.isLoading
          ? const AdminLoading(message: 'Cargando finanzas...')
          : RefreshIndicator(
              onRefresh: () => provider.load(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummary(provider),
                    const SizedBox(height: 24),
                    const AdminSectionTitle(title: 'HISTORIAL DE PAGOS'),
                    const SizedBox(height: 12),
                    _buildPayments(provider),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummary(AdminFinanceProvider provider) {
    final summary = provider.summary;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: AdminStatCard(label: 'INGRESOS', value: '\$${summary.totalRevenue.toStringAsFixed(2)}', icon: Icons.attach_money)),
            const SizedBox(width: 12),
            Expanded(child: AdminStatCard(label: 'NETO', value: '\$${summary.netRevenue.toStringAsFixed(2)}', icon: Icons.account_balance_wallet)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: AdminStatCard(label: 'COMISIONES', value: '\$${summary.commissions.toStringAsFixed(2)}', icon: Icons.receipt)),
            const SizedBox(width: 12),
            Expanded(child: AdminStatCard(label: 'ACTIVAS', value: '${summary.activeSubscriptions}', icon: Icons.star)),
          ],
        ),
      ],
    );
  }

  Widget _buildPayments(AdminFinanceProvider provider) {
    if (provider.payments.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.payment,
        title: 'No hay pagos registrados',
      );
    }
    return Column(
      children: provider.payments.map((payment) {
        final user = payment['profiles'] as Map<String, dynamic>?;
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
                payment['estado'] == 'completado' ? Icons.check_circle : Icons.schedule,
                color: payment['estado'] == 'completado' ? AppColors.positive : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?['nombre'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('\$${payment['monto'] ?? 0}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                _formatDate(payment['created_at']),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
