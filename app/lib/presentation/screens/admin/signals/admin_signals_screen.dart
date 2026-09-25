import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../providers/admin/admin_signals_provider.dart';
import '../../../../data/models/ventana_model.dart';
import '../widgets/admin_empty_state.dart';
import '../widgets/admin_loading.dart';
import '../widgets/admin_status_badge.dart';

class AdminSignalsScreen extends StatefulWidget {
  const AdminSignalsScreen({super.key});

  @override
  State<AdminSignalsScreen> createState() => _AdminSignalsScreenState();
}

class _AdminSignalsScreenState extends State<AdminSignalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminSignalsProvider>().subscribeRealtime();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminSignalsProvider>();

    return SafeArea(
      child: provider.isLoading && provider.ventanas.isEmpty
          ? const AdminLoading(message: 'Cargando señales...')
          : RefreshIndicator(
              onRefresh: () => provider.load(),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Señales', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Recibidas del MT5 en tiempo real',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (provider.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(provider.error!, style: const TextStyle(color: AppColors.negative)),
                    ),
                  if (provider.ventanas.isEmpty && !provider.isLoading)
                    const AdminEmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'No hay señales',
                      subtitle: 'Las señales del MT5 aparecerán aquí',
                    )
                  else
                    ...provider.ventanas.map((v) => _buildSignalCard(v)),
                ],
              ),
            ),
    );
  }

  Widget _buildSignalCard(VentanaModel v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AdminStatusBadge(
                label: v.estadoLabel,
                color: v.isActiva
                    ? AppColors.positive
                    : v.isCerrada
                        ? (v.isGanada ? AppColors.positive : v.isPerdida ? AppColors.negative : AppColors.textSecondary)
                        : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              AdminStatusBadge(
                label: v.isCompra ? 'ALZA' : 'BAJA',
                color: v.isCompra ? AppColors.positive : AppColors.negative,
                small: true,
              ),
              const Spacer(),
              Text(v.derivSymbol, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          _buildDetailRow('Dirección', v.isCompra ? 'Compra (ALZA)' : 'Venta (BAJA)'),
          if (v.resultado != null) _buildDetailRow('Resultado', _resultadoLabel(v.resultado!)),
          if (v.senalApertura != null) _buildDetailRow('Apertura', _formatTimestamp(v.senalApertura)),
          if (v.senalCierre != null) _buildDetailRow('Cierre', _formatTimestamp(v.senalCierre)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _resultadoLabel(String resultado) {
    switch (resultado) {
      case 'ganada':
        return 'Ganada';
      case 'perdida':
        return 'Perdida';
      case 'sin_operar':
        return 'Sin operar';
      default:
        return resultado;
    }
  }

  String _formatTimestamp(String? value) {
    if (value == null) return '-';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    final local = date.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
