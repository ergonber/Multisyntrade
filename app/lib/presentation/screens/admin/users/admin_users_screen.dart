import 'package:flutter/material.dart';
import 'admin_user_detail_screen.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../providers/admin/admin_users_provider.dart';
import '../../../../data/models/admin/admin_user_model.dart';
import '../widgets/admin_stat_card.dart';
import '../widgets/admin_empty_state.dart';
import '../widgets/admin_loading.dart';
import '../widgets/admin_status_badge.dart';

enum _FilterTab { todos, pendientes, activos, porVencer, vencidos }

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _FilterTab _selectedTab = _FilterTab.todos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUsersProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminUserModel> _applyFilter(AdminUsersProvider provider) {
    var users = provider.filter(_searchQuery);

    switch (_selectedTab) {
      case _FilterTab.pendientes:
        users = users.where((u) => u.isPending).toList();
      case _FilterTab.activos:
        users = users.where((u) => u.isActive && !u.isExpiringSoon).toList();
      case _FilterTab.porVencer:
        users = users.where((u) => u.isActive && u.isExpiringSoon).toList();
      case _FilterTab.vencidos:
        users = users.where((u) => u.isExpired || u.isCancelled).toList();
      case _FilterTab.todos:
        break;
    }

    return users;
  }

  int _tabCount(AdminUsersProvider provider, _FilterTab tab) {
    final all = provider.filter(_searchQuery);
    switch (tab) {
      case _FilterTab.todos:
        return all.length;
      case _FilterTab.pendientes:
        return all.where((u) => u.isPending).length;
      case _FilterTab.activos:
        return all.where((u) => u.isActive && !u.isExpiringSoon).length;
      case _FilterTab.porVencer:
        return all.where((u) => u.isActive && u.isExpiringSoon).length;
      case _FilterTab.vencidos:
        return all.where((u) => u.isExpired || u.isCancelled).length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminUsersProvider>();
    final filtered = _applyFilter(provider);

    return SafeArea(
      child: provider.isLoading && provider.users.isEmpty
          ? const AdminLoading(message: 'Cargando usuarios...')
          : RefreshIndicator(
              onRefresh: () => provider.load(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Usuarios', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildCounters(provider),
                    const SizedBox(height: 16),
                    AppInput(
                      controller: _searchController,
                      hintText: 'Buscar por correo, nombre o teléfono...',
                      prefixIcon: Icons.search,
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    const SizedBox(height: 12),
                    _buildFilterTabs(provider),
                    const SizedBox(height: 16),
                    if (provider.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(provider.error!, style: const TextStyle(color: AppColors.negative)),
                      ),
                    if (filtered.isEmpty)
                      const AdminEmptyState(
                        icon: Icons.people_outline,
                        title: 'No se encontraron usuarios',
                      )
                    else
                      ...filtered.map((user) => _buildUserTile(user, provider)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterTabs(AdminUsersProvider provider) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildTab('Todos', _FilterTab.todos, _tabCount(provider, _FilterTab.todos), Colors.grey),
          const SizedBox(width: 8),
          _buildTab('Pendientes', _FilterTab.pendientes, _tabCount(provider, _FilterTab.pendientes), AppColors.warning),
          const SizedBox(width: 8),
          _buildTab('Activos', _FilterTab.activos, _tabCount(provider, _FilterTab.activos), AppColors.positive),
          const SizedBox(width: 8),
          _buildTab('Por vencer', _FilterTab.porVencer, _tabCount(provider, _FilterTab.porVencer), AppColors.warning),
          const SizedBox(width: 8),
          _buildTab('Vencidos', _FilterTab.vencidos, _tabCount(provider, _FilterTab.vencidos), AppColors.negative),
        ],
      ),
    );
  }

  Widget _buildTab(String label, _FilterTab tab, int count, Color color) {
    final isSelected = _selectedTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? color : Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(AdminUserModel user) {
    if (user.isPending) return AppColors.warning;
    if (user.isActive && user.isExpiringSoon) return AppColors.warning;
    if (user.isActive) return AppColors.positive;
    if (user.isExpired || user.isCancelled) return AppColors.negative;
    return Colors.grey;
  }

  Widget _buildUserTile(AdminUserModel user, AdminUsersProvider provider) {
    final color = _statusColor(user);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AdminUserDetailScreen(userId: user.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.2),
              child: Text(
                user.initial,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      AdminStatusBadge(
                        label: user.subscriptionStatusLabel,
                        color: color,
                        small: true,
                      ),
                      if (user.subscriptionFechaFin != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(user.subscriptionFechaFin!),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (user.isPending || user.isExpired || user.isCancelled)
              _buildActivateButton(user, provider)
            else
              Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActivateButton(AdminUserModel user, AdminUsersProvider provider) {
    return GestureDetector(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.card,
            title: Text(user.isPending ? 'Activar cuenta' : 'Renovar suscripción'),
            content: Text(
              user.isPending
                  ? '¿Activar la cuenta de ${user.displayName} por 12 meses (VIP)?'
                  : '¿Renovar la suscripción de ${user.displayName} por 12 meses (VIP)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Activar', style: TextStyle(color: AppColors.positive)),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          final ok = await provider.activateSubscription(user.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok ? '${user.displayName} activado correctamente' : 'Error al activar acceso'),
                backgroundColor: ok ? AppColors.positive : AppColors.negative,
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.positive.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.positive.withOpacity(0.3)),
        ),
        child: const Text(
          'Activar acceso',
          style: TextStyle(color: AppColors.positive, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildCounters(AdminUsersProvider provider) {
    final pending = provider.users.where((u) => u.isPending).length;
    final active = provider.users.where((u) => u.isActive && !u.isExpiringSoon).length;
    final expiring = provider.users.where((u) => u.isActive && u.isExpiringSoon).length;
    final expired = provider.users.where((u) => u.isExpired || u.isCancelled).length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: AdminStatCard(label: 'TOTAL', value: '${provider.totalUsers}')),
            const SizedBox(width: 8),
            Expanded(child: AdminStatCard(label: 'PENDIENTES', value: '$pending', valueColor: AppColors.warning)),
            const SizedBox(width: 8),
            Expanded(child: AdminStatCard(label: 'ACTIVOS', value: '$active', valueColor: AppColors.positive)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: AdminStatCard(label: 'POR VENCER', value: '$expiring', valueColor: AppColors.warning)),
            const SizedBox(width: 8),
            Expanded(child: AdminStatCard(label: 'VENCIDOS', value: '$expired', valueColor: AppColors.negative)),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}
