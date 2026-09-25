import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../providers/admin/admin_operations_provider.dart';
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
                                    AdminStatusBadge(
                                      label: op.estado,
                                      color: op.isExecuted ? AppColors.positive :
                                             op.isPending ? AppColors.warning : AppColors.textSecondary,
                                      small: true,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${op.derivSymbol ?? ''} ${op.direccion ?? ''}',
                                              style: const TextStyle(fontWeight: FontWeight.w500)),
                                          Text('x${op.multiplicador ?? 0} - \$${op.monto?.toStringAsFixed(2) ?? '0'}',
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    if (op.ganancia != null)
                                      Text(
                                        '${op.ganancia! >= 0 ? '+' : ''}\$${op.ganancia!.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: op.ganancia! >= 0 ? AppColors.positive : AppColors.negative,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
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
          DropdownMenuItem(value: 'pendiente', child: Text('Pendientes', style: TextStyle(fontSize: 12))),
          DropdownMenuItem(value: 'ejecutada', child: Text('Ejecutadas', style: TextStyle(fontSize: 12))),
        ],
        onChanged: (v) => provider.setFilter(v),
      ),
    );
  }
}
