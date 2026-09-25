import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_colors.dart';

class HomeShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const HomeShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: Colors.grey[800]!, width: 0.5)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(context, 0, Icons.home_outlined, Icons.home, 'Home'),
                _buildNavItem(context, 1, Icons.show_chart_outlined, Icons.show_chart, 'Señales'),
                _buildNavItem(context, 2, Icons.bar_chart_outlined, Icons.bar_chart, 'Stats'),
                _buildNavItem(context, 3, Icons.more_horiz_outlined, Icons.more_horiz, 'Más'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, IconData activeIcon, String label) {
    final isActive = navigationShell.currentIndex == index;
    return GestureDetector(
      onTap: () => navigationShell.goBranch(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : Colors.grey, size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: isActive ? AppColors.primary : Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}
