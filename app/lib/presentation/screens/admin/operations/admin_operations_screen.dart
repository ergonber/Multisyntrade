import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../providers/admin/admin_operations_provider.dart';
import '../../../../data/models/admin/operation_model.dart';
import '../widgets/admin_empty_state.dart';
import '../widgets/admin_loading.dart';
import '../widgets/admin_status_badge.dart';

class AdminOperationsScreen extends StatefulWidget {
  const AdminOperationsScreen({super.key});

  @override
  State<AdminOperationsScreen> createState() => _AdminOperationsScreenState();
}

class _AdminOperationsScreenState extends State<AdminOperationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminOperationsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminOperationsProvider>();

    return SafeArea(
      child: provider.isLoading && provider.operations.isEmpty
          ? const AdminLoading(message: 'Cargando operaciones...')
          : RefreshIndicator(
              onRefresh: () => provider.load(),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Operaciones', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        _buildFilterDropdown(provider),
                      ],
                    ),
                  ),
                  if (provider.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(provider.error!, style: const TextStyle(color: AppColors.negative)),
                    ),
                  Expanded(
                    child: provider.filtered.isEmpty
                        ? const AdminEmptyState(
                            icon: Icons.show_chart_outlined,
                            title: 'No hay operaciones',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: provider.filtered.length,
                            itemBuilder: (context, index) {
                              final op = provider.filtered[index];
                              return _buildOperationCard(op);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOperationCard(OperationModel op) {
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
                label: op.estadoLabel,
                color: _estadoColor(op),
                small: true,
              ),
              const Spacer(),
              Text(
                _formatDate(op.createdAt),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      op.userName ?? 'Sin usuario',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _assetLabel(op),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Monto: \$${(op.monto ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (op.resultado != null)
                Text(
                  '${op.resultado! >= 0 ? '+' : ''}\$${op.resultado!.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: op.resultado! >= 0 ? AppColors.positive : AppColors.negative,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _assetLabel(OperationModel op) {
    final symbol = op.derivSymbol ?? op.activo ?? '-';
    if (op.direccion != null && op.direccion!.isNotEmpty) {
      return '$symbol · ${op.direccion!}';
    }
    return symbol;
  }

  Color _estadoColor(OperationModel op) {
    if (op.isWin) return AppColors.positive;
    if (op.isLoss) return AppColors.negative;
    if (op.isEnCurso) return AppColors.warning;
    if (op.isRechazada) return AppColors.negative;
    if (op.isCancelada) return AppColors.textSecondary;
    return AppColors.textSecondary;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _buildFilterDropdown(AdminOperationsProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: DropdownButton<String?>(
        value: provider.filterEstado,
        dropdownColor: AppColors.card,
        underline: const SizedBox(),
        isDense: true,
        items: const [
          DropdownMenuItem(value: null, child: Text('Todos', style: TextStyle(fontSize: 12))),
          DropdownMenuItem(value: 'en_curso', child: Text('En curso', style: TextStyle(fontSize: 12))),
          DropdownMenuItem(value: 'ganada', child: Text('Ganadas', style: TextStyle(fontSize: 12))),
          DropdownMenuItem(value: 'perdida', child: Text('Perdidas', style: TextStyle(fontSize: 12))),
          DropdownMenuItem(value: 'rechazada', child: Text('Rechazadas', style: TextStyle(fontSize: 12))),
          DropdownMenuItem(value: 'cancelada', child: Text('Canceladas', style: TextStyle(fontSize: 12))),
        ],
        onChanged: (v) => provider.setFilter(v),
      ),
    );
  }
}
