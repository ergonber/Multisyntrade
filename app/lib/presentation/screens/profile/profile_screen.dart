import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../auth/login_screen.dart';
import '../deriv/deriv_connect_screen.dart';
import '../admin/admin_shell.dart';
import 'capital_risk_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Perfil', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, size: 40, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(auth.userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(auth.userEmail, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStat('Capital', '\$${(profile?.capitalInicial ?? 0).toStringAsFixed(0)}'),
                      _buildStat('Riesgo', '${profile?.riskPercentage ?? 2}%'),
                      _buildStat('Plan', profile?.rol ?? 'user'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _ProfileMenuItem(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Conexión Deriv',
              badge: profile?.isDerivConnected == true ? 'Conectada' : 'Desconectada',
              badgeColor: profile?.isDerivConnected == true ? AppColors.primary : AppColors.negative,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DerivConnectScreen())),
            ),
            const SizedBox(height: 12),
            _ProfileMenuItem(
              icon: Icons.star_outline,
              title: 'Mi Plan',
              badge: _planBadgeLabel(auth),
              badgeColor: _planBadgeColor(auth),
            ),
            const SizedBox(height: 12),
            _ProfileMenuItem(
              icon: Icons.account_balance,
              title: 'Capital y Riesgo',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CapitalRiskScreen())),
            ),
            const SizedBox(height: 12),
            const _ProfileMenuItem(
              icon: Icons.assessment_outlined,
              title: 'Objetivos Financieros',
            ),
            const SizedBox(height: 12),
            const _ProfileMenuItem(icon: Icons.history, title: 'Historial'),
            const SizedBox(height: 12),
            const _ProfileMenuItem(icon: Icons.notifications_outlined, title: 'Notificaciones'),
            const SizedBox(height: 12),
            const _ProfileMenuItem(icon: Icons.help_outline, title: 'Ayuda y Soporte'),
            const SizedBox(height: 12),
            const _ProfileMenuItem(icon: Icons.settings_outlined, title: 'Configuración'),
            if (AppConfig.isAdminEntry && auth.isAdmin) ...[
              const SizedBox(height: 12),
              _ProfileMenuItem(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Panel de Administración',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminShell()),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showLogoutDialog(context, auth),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.negative),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('CERRAR SESIÓN', style: TextStyle(color: AppColors.negative)),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text('SynTrade v${const String.fromEnvironment('APP_VERSION', defaultValue: '2.0.0')}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
            child: const Text('Cerrar Sesión', style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  String _planBadgeLabel(AuthProvider auth) {
    if (auth.isPending) return 'Pendiente';
    if (auth.isExpired) return 'Vencida';
    if (auth.isCancelled) return 'Cancelada';
    if (auth.hasAccess) {
      final plan = auth.subscriptionPlan ?? 'vip';
      if (auth.subscriptionFechaFin != null) {
        final days = auth.subscriptionFechaFin!.difference(DateTime.now()).inDays;
        if (days <= 7) return 'VIP ($days días)';
      }
      return 'VIP';
    }
    return auth.subscriptionPlan ?? 'Sin plan';
  }

  Color _planBadgeColor(AuthProvider auth) {
    if (auth.isPending) return AppColors.warning;
    if (auth.isExpired || auth.isCancelled) return AppColors.negative;
    if (auth.hasAccess) {
      if (auth.subscriptionFechaFin != null) {
        final days = auth.subscriptionFechaFin!.difference(DateTime.now()).inDays;
        if (days <= 7) return AppColors.warning;
      }
      return AppColors.positive;
    }
    return Colors.grey;
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback? onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    this.badge,
    this.badgeColor,
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
            Icon(icon, color: Colors.grey, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 15)),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppColors.primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!,
                    style: TextStyle(
                        color: badgeColor ?? AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }
}

