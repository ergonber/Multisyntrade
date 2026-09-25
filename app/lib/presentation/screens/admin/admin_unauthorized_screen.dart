import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../home/home_screen.dart';

class AdminUnauthorizedScreen extends StatelessWidget {
  const AdminUnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: AppColors.negative, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'No autorizado',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No tienes permisos para acceder al panel de administración.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: 'VOLVER AL INICIO',
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
