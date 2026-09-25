import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../announcements/announcements_screen.dart';
import '../finance/admin_finance_screen.dart';
import '../config/admin_config_screen.dart';
import '../profile/admin_edit_profile_screen.dart';

class AdminMoreScreen extends StatelessWidget {
  const AdminMoreScreen({super.key});

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
              icon: Icons.campaign_outlined,
              title: 'Anuncios',
              subtitle: 'Gestiona los anuncios de la app',
              onTap: () => _push(context, const AnnouncementsScreen()),
            ),
            const SizedBox(height: 12),
            _MenuItem(
              icon: Icons.attach_money,
              title: 'Finanzas',
              subtitle: 'Resumen de ingresos y pagos',
              onTap: () => _push(context, const AdminFinanceScreen()),
            ),
            const SizedBox(height: 12),
            _MenuItem(
              icon: Icons.settings_outlined,
              title: 'Configuración',
              subtitle: 'Mantenimiento y ajustes',
              onTap: () => _push(context, const AdminConfigScreen()),
            ),
            const SizedBox(height: 12),
            _MenuItem(
              icon: Icons.person_outline,
              title: 'Editar Perfil',
              subtitle: 'Tu información de administrador',
              onTap: () => _push(context, const AdminEditProfileScreen()),
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

void _push(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}
