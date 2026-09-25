import 'package:flutter/material.dart';
import 'new_signal_screen.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../providers/admin/admin_signals_provider.dart';
import '../../../../data/models/trade_execution_model.dart';
import '../widgets/admin_section_title.dart';
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
      context.read<AdminSignalsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminSignalsProvider>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_signal_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Señal'),
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewSignalScreen()));
          provider.load();
        },
      ),
      body: provider.isLoading && provider.ventanas.isEmpty
          ? const AdminLoading(message: 'Cargando señales...')
          : RefreshIndicator(
              onRefresh: () => provider.load(),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Señales', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                          AppButton(
                            label: 'Nueva',
                            icon: Icons.add,
                            height: 40,
                            onPressed: () async {
                              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewSignalScreen()));
                              provider.load();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (provider.error != null)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(
                        child: Text(provider.error!, style: const TextStyle(color: AppColors.negative)),
                      ),
                    ),
                  if (provider.programadas.isNotEmpty) ...[
                    const SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      sliver: SliverToBoxAdapter(child: AdminSectionTitle(title: 'PROGRAMADAS')),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.builder(
                        itemCount: provider.programadas.length,
                        itemBuilder: (context, index) {
                          final v = provider.programadas[index];
                          return _buildSignalCard(v, provider, 'programada');
                        },
                      ),
                    ),
                  ],
                  if (provider.activas.isNotEmpty) ...[
                    const SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      sliver: SliverToBoxAdapter(child: AdminSectionTitle(title: 'ACTIVAS')),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.builder(
                        itemCount: provider.activas.length,
                        itemBuilder: (context, index) {
                          final v = provider.activas[index];
                          return _buildSignalCard(v, provider, 'activa');
                        },
                      ),
                    ),
                  ],
                  if (provider.cerradas.isNotEmpty) ...[
                    const SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      sliver: SliverToBoxAdapter(child: AdminSectionTitle(title: 'CERRADAS')),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.builder(
                        itemCount: provider.cerradas.length,
                        itemBuilder: (context, index) {
                          final v = provider.cerradas[index];
                          return _buildSignalCard(v, provider, 'cerrada');
                        },
                      ),
                    ),
                  ],
                  if (provider.ventanas.isEmpty && !provider.isLoading)
                    const SliverPadding(
                      padding: EdgeInsets.all(40),
                      sliver: SliverToBoxAdapter(
                        child: AdminEmptyState(
                          icon: Icons.campaign_outlined,
                          title: 'No hay señales',
                          subtitle: 'Crea una nueva señal para comenzar',
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSignalCard(dynamic v, AdminSignalsProvider provider, String section) {
    final myExec = provider.getMyExecutionForVentana(v.id);
    final hasResult = myExec != null && myExec.resultado != null && myExec.resultado != 0;
    final capital = provider.myCapital;

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
                label: myExec != null
                    ? (myExec.isGanada ? 'Ganada' : myExec.isPerdida ? 'Perdida' : v.estadoLabel)
                    : v.estadoLabel,
                color: myExec != null
                    ? (myExec.isGanada ? AppColors.positive : myExec.isPerdida ? AppColors.negative : AppColors.textSecondary)
                    : (v.isActiva ? AppColors.positive : AppColors.textSecondary),
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
          if (v.titulo != null) ...[
            const SizedBox(height: 8),
            Text(v.titulo!, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (v.multiplicador != null)
                Text('x${v.multiplicador!.toInt()}', style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (section == 'cerrada' && hasResult) ...[
                _buildPnlBadge(myExec, capital),
                const SizedBox(width: 8),
              ] else if (section == 'cerrada' && myExec == null) ...[
                Text('—', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(width: 8),
              ],
              if (section == 'programada') ...[
                _buildActionButton('Publicar', AppColors.positive, () => provider.publish(v.id)),
                const SizedBox(width: 8),
                _buildActionButton('Cancelar', AppColors.negative, () => provider.cancel(v.id)),
              ] else if (section == 'activa') ...[
                _buildActionButton('CERRAR SEÑAL', AppColors.warning, () => _confirmClose(v.id)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPnlBadge(TradeExecutionModel exec, double capital) {
    final resultado = exec.resultado ?? 0;
    final isPositive = resultado >= 0;
    final color = isPositive ? AppColors.positive : AppColors.negative;
    final sign = isPositive ? '+' : '';
    final pct = capital > 0 ? (resultado / capital) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$sign\$${resultado.toStringAsFixed(2)} ($sign${pct.toStringAsFixed(1)}%)',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  void _confirmClose(String ventanaId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Cerrar Señal'),
        content: const Text(
          '¿Cerrar esta señal? Se venderán todos los contratos y se calculará el resultado real.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await context.read<AdminSignalsProvider>().closeSignal(ventanaId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Señal cerrada. Contratos vendiéndose en segundo plano.'
                        : 'Error al cerrar señal.'),
                    backgroundColor: ok ? AppColors.primary : AppColors.negative,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('CERRAR', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
