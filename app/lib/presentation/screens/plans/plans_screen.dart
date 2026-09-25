import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../core/widgets/app_card.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planes')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PlanCard(
            name: 'Gratuito',
            price: '\$0',
            period: 'Siempre',
            features: [
              'Ver señales en tiempo real',
              'Historial básico',
              '1 cuenta conectada',
            ],
            isSelected: true,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          _PlanCard(
            name: 'Básico',
            price: '\$29',
            period: '/mes',
            features: [
              'Todo lo del plan gratuito',
              'Auto-copy trading',
              'Estadísticas avanzadas',
              'Soporte prioritario',
            ],
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          _PlanCard(
            name: 'Pro',
            price: '\$79',
            period: '/mes',
            features: [
              'Todo lo del plan Básico',
              'Múltiples cuentas',
              'Simulador ilimitado',
              'Análisis personalizado',
              'API acceso',
            ],
            color: AppColors.warning,
          ),
          const SizedBox(height: 16),
          _PlanCard(
            name: 'VIP',
            price: '\$149',
            period: '/mes',
            features: [
              'Todo lo del plan Pro',
              'Señales exclusivas',
              'Gestor de cuenta dedicado',
              'Acceso anticipado a funciones',
              'Sin límites',
            ],
            color: const Color(0xFFFF6B6B),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final String period;
  final List<String> features;
  final bool isSelected;
  final Color color;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    this.isSelected = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: isSelected ? color.withOpacity(0.1) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('ACTUAL', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              Text(period, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
