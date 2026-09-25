import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      await auth.updatePassword(_passwordController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contraseña actualizada.'),
            backgroundColor: AppColors.positive,
          ),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.negative),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset, color: AppColors.primary, size: 40),
                ),
                const SizedBox(height: 24),
                const Text('Nueva Contraseña',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Ingresá tu nueva contraseña.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(height: 40),
                const Text('NUEVA CONTRASEÑA',
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: 24),
                const Text('CONFIRMAR CONTRASEÑA',
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirmá tu contraseña';
                    if (v != _passwordController.text) return 'Las contraseñas no coinciden';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: 'ACTUALIZAR CONTRASEÑA',
                  isLoading: _isLoading,
                  onPressed: _updatePassword,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
