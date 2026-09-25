import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/deriv_provider.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();
    final deriv = context.watch<DerivProvider>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estadísticas',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Conoce tu evolución y toma mejores decisiones.',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('SALDO DISPONIBLE', style: TextStyle(color: Colors.grey, fontSize: 10)),
                      const Text('En Deriv', style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('\$${(profile.profile?.capitalInicial ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: deriv.isConnected
                              ? AppColors.positive.withOpacity(0.1)
                              : AppColors.negative.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: deriv.isConnected ? AppColors.positive : AppColors.negative,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              deriv.isConnected ? 'Conectado' : 'Desconectado',
                              style: TextStyle(
                                color: deriv.isConnected ? AppColors.positive : AppColors.negative,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _MiniStat(label: 'OPERACIONES', value: '${profile.stats?.totalTrades ?? 0}'),
                      const SizedBox(width: 16),
                      _MiniStat(label: 'GANADAS', value: '${profile.stats?.wins ?? 0}'),
                      const SizedBox(width: 16),
                      _MiniStat(label: 'PERDIDAS', value: '${profile.stats?.losses ?? 0}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MiniStat(
                          label: 'WIN RATE',
                          value: '${(profile.stats?.winRate ?? 0).toStringAsFixed(0)}%',
                          color: AppColors.positive),
                      const SizedBox(width: 16),
                      _MiniStat(
                          label: 'PNL TOTAL',
                          value: Formatters.currency(profile.stats?.totalPnl ?? 0),
                          color: (profile.stats?.totalPnl ?? 0) >= 0
                              ? AppColors.positive
                              : AppColors.negative),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color ?? Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }
}
