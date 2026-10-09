import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;
  bool _sending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.resetPassword(_emailController.text.trim());
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      setState(() => _emailSent = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'No se pudo enviar el correo.'),
          backgroundColor: AppColors.negative,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar Contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _emailSent ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const SizedBox(height: 80),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read, color: AppColors.primary, size: 40),
        ),
        const SizedBox(height: 24),
        const Text('Correo Enviado',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text(
          'Revisa tu bandeja de entrada y sigue las instrucciones para restablecer tu contraseña.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[400]),
        ),
        const SizedBox(height: 32),
        AppButton(
          label: 'VOLVER AL LOGIN',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_reset, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 24),
          const Text('¿Olvidaste tu contraseña?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Ingresa tu correo electrónico y te enviaremos las instrucciones para restablecerla.',
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 40),
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
          const SizedBox(height: 32),
          AppButton(
            label: 'ENVIAR INSTRUCCIONES',
            isLoading: _sending,
            onPressed: _sendReset,
          ),
        ],
      ),
    );
  }
}
