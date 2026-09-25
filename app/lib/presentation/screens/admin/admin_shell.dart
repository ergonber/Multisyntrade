import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../presentation/providers/auth_provider.dart';
import 'admin_unauthorized_screen.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'users/admin_users_screen.dart';
import 'signals/admin_signals_screen.dart';
import 'operations/admin_operations_screen.dart';
import 'more/admin_more_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const List<Widget> _screens = [
    AdminDashboardScreen(),
    AdminUsersScreen(),
    AdminSignalsScreen(),
    AdminOperationsScreen(),
    AdminMoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.initial || auth.status == AuthStatus.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!auth.isAdmin) {
      return const AdminUnauthorizedScreen();
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: Colors.grey[800]!, width: 0.5)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Panel'),
                _buildNavItem(1, Icons.people_outline, Icons.people, 'Usuarios'),
                _buildNavItem(2, Icons.campaign_outlined, Icons.campaign, 'Señales'),
                _buildNavItem(3, Icons.show_chart_outlined, Icons.show_chart, 'Operaciones'),
                _buildNavItem(4, Icons.more_horiz_outlined, Icons.more_horiz, 'Más'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _index == index;
    return GestureDetector(
      onTap: () => setState(() => _index = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : Colors.grey, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: isActive ? AppColors.primary : Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}
