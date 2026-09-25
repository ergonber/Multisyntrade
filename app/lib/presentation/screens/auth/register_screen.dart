import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import '../subscription/subscription_gate_screen.dart';
import '../admin/admin_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (mounted && success) {
      if (auth.isAuthenticated) {
        if (auth.isAdmin) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminShell()));
        } else if (auth.hasAccess) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cuenta creada. Tu acceso está pendiente de activación por el administrador.'),
              backgroundColor: AppColors.primary,
              duration: Duration(seconds: 5),
            ),
          );
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SubscriptionGateScreen()));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta creada.'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } else if (mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: AppColors.negative),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Text('NOMBRE COMPLETO',
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Ej. Alexander Hamilton',
                    prefixIcon: Icon(Icons.person_outline, color: Colors.grey),
                  ),
                  validator: (v) => Validators.required(v, 'tu nombre'),
                ),
                const SizedBox(height: 24),
                const Text('CORREO ELECTRÓNICO',
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'nombre@ejemplo.com',
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.grey),
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: 24),
                const Text('CONTRASEÑA',
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
                const SizedBox(height: 32),
                AppButton(
                  label: 'CREAR CUENTA',
                  isLoading: auth.status == AuthStatus.loading,
                  onPressed: _register,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
