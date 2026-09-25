import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../providers/admin/admin_users_provider.dart';
import '../../../../data/models/admin/admin_user_model.dart';
import '../widgets/admin_section_title.dart';
import '../widgets/admin_empty_state.dart';
import '../widgets/admin_loading.dart';
import '../widgets/admin_status_badge.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final String userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  AdminUserModel? _user;
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<AdminUsersProvider>();
    if (provider.users.isEmpty) await provider.load();

    final user = provider.users.where((u) => u.id == widget.userId).firstOrNull;
    final payments = await provider.getPayments(widget.userId);

    setState(() {
      _user = user;
      _payments = payments;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: AdminLoading());
    if (_user == null) return const Scaffold(body: AdminEmptyState(icon: Icons.error, title: 'Usuario no encontrado'));

    final provider = context.watch<AdminUsersProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_user!.nombre),
        actions: [
          IconButton(
            icon: Icon(_user!.isActive ? Icons.lock_open : Icons.lock),
            tooltip: _user!.isActive ? 'Desactivar' : 'Activar',
            onPressed: () async {
              await provider.toggleStatus(_user!.id);
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_user!.isActive ? 'Usuario desactivado' : 'Usuario activado'),
                    backgroundColor: AppColors.positive,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            const AdminSectionTitle(title: 'SUSCRIPCIÓN'),
            const SizedBox(height: 12),
            _buildSubscriptionCard(),
            const SizedBox(height: 24),
            const AdminSectionTitle(title: 'ROL'),
            const SizedBox(height: 12),
            _buildRoleSelector(),
            const SizedBox(height: 24),
            const AdminSectionTitle(title: 'CAMBIAR PLAN'),
            const SizedBox(height: 12),
            _buildPlanSelector(),
            const SizedBox(height: 24),
            const AdminSectionTitle(title: 'HISTORIAL DE PAGOS'),
            const SizedBox(height: 12),
            _buildPayments(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final displayName = _user!.nombre.isNotEmpty ? _user!.nombre : (_user!.email ?? 'Sin nombre');
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
          child: Text(
            _user!.initial,
            style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              if (_user!.email != null && _user!.email!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(_user!.email!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
              const SizedBox(height: 4),
              AdminStatusBadge(
                label: _user!.isActive ? 'Activa' : 'Inactiva',
                color: _user!.isActive ? AppColors.positive : AppColors.negative,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard() {
    final color = _user!.isActive
        ? (_user!.isExpiringSoon ? AppColors.warning : AppColors.positive)
        : _user!.isPending
            ? AppColors.warning
            : AppColors.negative;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.star, color: _user!.plan == 'vip' ? AppColors.warning : AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan: ${_user!.plan ?? 'Sin plan'}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (_user!.subscriptionFechaFin != null)
                      Text(
                        'Vence: ${_user!.subscriptionFechaFin!.day}/${_user!.subscriptionFechaFin!.month}/${_user!.subscriptionFechaFin!.year}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                  ],
                ),
              ),
              AdminStatusBadge(
                label: _user!.subscriptionStatusLabel,
                color: color,
                small: true,
              ),
            ],
          ),
          if (_user!.isPending || _user!.isExpired || _user!.isCancelled) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _activateSubscription(),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(_user!.isPending ? 'ACTIVAR CUENTA' : 'RENOVAR SUSCRIPCIÓN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.positive,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _activateSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(_user!.isPending ? 'Activar cuenta' : 'Renovar suscripción'),
        content: Text(
          _user!.isPending
              ? '¿Activar la cuenta de ${_user!.displayName} por 12 meses (VIP)?'
              : '¿Renovar la suscripción de ${_user!.displayName} por 12 meses (VIP)?',
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

    if (confirmed == true && mounted) {
      await context.read<AdminUsersProvider>().activateSubscription(_user!.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suscripción activada correctamente'),
            backgroundColor: AppColors.positive,
          ),
        );
      }
    }
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          const Text('Rol:', style: TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          DropdownButton<String>(
            value: _user!.rol,
            dropdownColor: AppColors.card,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'user', child: Text('Usuario')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (value) async {
              if (value != null) {
                await context.read<AdminUsersProvider>().setRole(_user!.id, value);
                await _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_membership, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text('Plan actual: ${_user!.plan ?? 'Sin plan'}', style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          AdminStatusBadge(
            label: _user!.subscriptionStatusLabel,
            color: _user!.isActive ? AppColors.positive : AppColors.negative,
            small: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPayments() {
    if (_payments.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.payment,
        title: 'Sin pagos registrados',
      );
    }
    return Column(
      children: _payments.map((payment) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(
                payment['estado'] == 'completado' ? Icons.check_circle : Icons.schedule,
                color: payment['estado'] == 'completado' ? AppColors.positive : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('\$${payment['monto'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(payment['estado'] ?? '-',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                _formatDate(payment['created_at']),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
