import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/goals_provider.dart';
import 'crear_meta_screen.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Objetivos Financieros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CrearMetaScreen()),
            ),
          ),
        ],
      ),
      body: goals.isLoading
          ? const Center(child: CircularProgressIndicator())
          : goals.metas.isEmpty
              ? _buildEmptyState(context)
              : _buildGoalsList(context, goals),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_flags_outlined, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('Sin objetivos',
              style: TextStyle(fontSize: 20, color: Colors.grey[400])),
          const SizedBox(height: 8),
          Text('Crea tu primer objetivo financiero',
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          AppButton(
            label: 'CREAR OBJETIVO',
            icon: Icons.add,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CrearMetaScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsList(BuildContext context, GoalsProvider goals) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: goals.metas.length,
      itemBuilder: (context, index) {
        final meta = goals.metas[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (meta.imagenUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(meta.imagenUrl!, width: 48, height: 48, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.flag, color: AppColors.primary),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(meta.objetivo,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: meta.isCompleted
                                  ? AppColors.positive.withOpacity(0.1)
                                  : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              meta.isCompleted ? 'Completado' : 'En progreso',
                              style: TextStyle(
                                color: meta.isCompleted ? AppColors.positive : AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text('${meta.progressPercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: AppColors.positive,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SAVED AMOUNT', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                    Text('${meta.progressPercent.toStringAsFixed(0)}% COMPLETED',
                        style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${Formatters.currency(meta.progreso)} of \$${Formatters.currency(meta.montoMeta)}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: meta.progressPercent / 100,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Estimated completion: ${meta.estimatedCompletion}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }
}
