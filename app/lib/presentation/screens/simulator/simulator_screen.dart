import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../providers/simulator_provider.dart';

class SimulatorScreen extends StatelessWidget {
  const SimulatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sim = context.watch<SimulatorProvider>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Simulador',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Proyecta tus rendimientos basados en señales enviadas a los suscriptores VIP.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 32),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('CAPITAL OPERATIVO',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('\$USD',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('\$${sim.capital.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Slider(
                    value: sim.capital,
                    min: 100,
                    max: 50000,
                    divisions: 50,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.border,
                    onChanged: sim.setCapital,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('PERFIL DE RIESGO',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${sim.riskPercent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: sim.riskPercent,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: AppColors.warning,
                    inactiveColor: AppColors.border,
                    onChanged: sim.setRiskPercent,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('CONSERVADOR', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                      Text('AGRESIVO', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DURACIÓN DEL CICLO',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _CycleButton(
                        label: '24 HORAS',
                        icon: Icons.access_time,
                        isSelected: sim.cycleHours == 24,
                        onTap: () => sim.setCycleHours(24),
                      ),
                      const SizedBox(width: 12),
                      _CycleButton(
                        label: '48 HORAS',
                        icon: Icons.access_time,
                        isSelected: sim.cycleHours == 48,
                        onTap: () => sim.setCycleHours(48),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Un riesgo del 3% al 5% optimiza el crecimiento compuesto sin comprometer la liquidez.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: Column(
                      children: [
                        const Text('GANANCIA ESTIMADA',
                            style: TextStyle(color: Colors.grey, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text('+\$${sim.estimatedProfit.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: AppColors.positive,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    child: Column(
                      children: [
                        const Text('ROI PROYECTADO',
                            style: TextStyle(color: Colors.grey, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text('${sim.projectedROI.toStringAsFixed(1)}%',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: sim.isSimulating ? null : () => sim.runSimulation(),
              child: sim.isSimulating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('INICIAR SIMULACIÓN'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: Colors.black),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _CycleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CycleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.black : Colors.grey, size: 18),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: isSelected ? Colors.black : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
