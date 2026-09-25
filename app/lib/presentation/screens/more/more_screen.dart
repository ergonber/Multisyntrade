import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../core/widgets/section_header.dart';
import '../stats/stats_screen.dart';
import '../simulator/simulator_screen.dart';
import '../goals/goals_screen.dart';
import '../plans/plans_screen.dart';
import '../deriv/deriv_connect_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Más', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _MenuItem(
              icon: Icons.show_chart,
              title: 'Estadísticas',
              subtitle: 'Tu rendimiento detallado',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
            ),
            const SizedBox(height: 12),
            _MenuItem(
              icon: Icons.science_outlined,
              title: 'Simulador',
              subtitle: 'Proyecta tus ganancias',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SimulatorScreen())),
            ),
            const SizedBox(height: 12),
            _MenuItem(
              icon: Icons.flag_outlined,
              title: 'Objetivos',
              subtitle: 'Metas financieras',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
            ),
            const SizedBox(height: 12),
            _MenuItem(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Conexión Deriv',
              subtitle: 'Gestiona tu cuenta',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DerivConnectScreen())),
            ),
            const SizedBox(height: 12),
            _MenuItem(
              icon: Icons.star_outline,
              title: 'Planes',
              subtitle: 'Mejora tu plan',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlansScreen())),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'SOPORTE'),
            const SizedBox(height: 12),
            _MenuItem(
              icon: Icons.help_outline,
              title: 'Ayuda y Soporte',
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _MenuItem(
              icon: Icons.description_outlined,
              title: 'Términos y Condiciones',
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _MenuItem(
              icon: Icons.privacy_tip_outlined,
              title: 'Política de Privacidad',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }
}
