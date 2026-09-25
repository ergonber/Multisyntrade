import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/utils/validators.dart';
import '../../../providers/profile_provider.dart';
import '../../../../data/repositories/admin/admin_config_repository.dart';

class AdminEditProfileScreen extends StatefulWidget {
  const AdminEditProfileScreen({super.key});

  @override
  State<AdminEditProfileScreen> createState() => _AdminEditProfileScreenState();
}

class _AdminEditProfileScreenState extends State<AdminEditProfileScreen> {
  final _nombreController = TextEditingController();
  final _repo = AdminConfigRepository();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<ProfileProvider>().profile;
      if (profile != null) {
        _nombreController.text = profile.nombre;
      }
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nombreController.text.isEmpty) return;

    final profile = context.read<ProfileProvider>().profile;
    if (profile == null) return;

    setState(() => _isLoading = true);
    try {
      await _repo.updateProfile(userId: profile.id, nombre: _nombreController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado'), backgroundColor: AppColors.positive),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.negative),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: const Icon(Icons.person, size: 48, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            AppInput(
              controller: _nombreController,
              labelText: 'NOMBRE',
              hintText: 'Tu nombre',
              prefixIcon: Icons.person_outline,
              validator: (v) => Validators.required(v, 'el nombre'),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'GUARDAR',
              isLoading: _isLoading,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
