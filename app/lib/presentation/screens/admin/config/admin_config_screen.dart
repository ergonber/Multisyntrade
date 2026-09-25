import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../providers/admin/admin_config_provider.dart';
import '../widgets/admin_loading.dart';

class AdminConfigScreen extends StatefulWidget {
  const AdminConfigScreen({super.key});

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminConfigProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminConfigProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: provider.isLoading
          ? const AdminLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mantenimiento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.build_circle_outlined, color: AppColors.warning, size: 24),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Modo Mantenimiento', style: TextStyle(fontWeight: FontWeight.w500)),
                              Text('Bloquea el acceso a la app para usuarios', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        Switch(
                          value: provider.config.maintenanceMode,
                          onChanged: (v) => provider.toggleMaintenance(v),
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  if (provider.config.maintenanceMode) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              provider.config.maintenanceMessage ?? 'App en mantenimiento',
                              style: const TextStyle(color: AppColors.warning, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  const Text('Versión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.primary, size: 24),
                        const SizedBox(width: 16),
                        Text(provider.config.appVersion ?? '1.0.0',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
