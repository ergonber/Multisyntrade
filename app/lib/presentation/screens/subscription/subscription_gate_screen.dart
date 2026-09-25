import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class SubscriptionGateScreen extends StatefulWidget {
  const SubscriptionGateScreen({super.key});

  @override
  State<SubscriptionGateScreen> createState() => _SubscriptionGateScreenState();
}

class _SubscriptionGateScreenState extends State<SubscriptionGateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final uid = auth.currentUser?.id;
      if (uid != null) context.read<SubscriptionProvider>().loadSubscription(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _iconColor(sub.status).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconForStatus(sub.status), size: 48, color: _iconColor(sub.status)),
                ),
                const SizedBox(height: 32),
                Text(
                  _titleForStatus(sub.status),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  _messageForStatus(sub.status),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                ),
                if (sub.status == SubscriptionStatus.active) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Vence: ${sub.subscription?.fechaFin.day}/${sub.subscription?.fechaFin.month}/${sub.subscription?.fechaFin.year}',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _onAction(context, sub, auth),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _buttonLabel(sub.status),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    await auth.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                  child: const Text('Cerrar sesión', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onAction(BuildContext context, SubscriptionProvider sub, AuthProvider auth) {
    if (sub.status == SubscriptionStatus.active) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    // Para pendiente/vencida/cancelada, cerrar sesión
    () async {
      await auth.signOut();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }();
  }

  String _titleForStatus(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.pending:
        return 'Cuenta pendiente\nde activación';
      case SubscriptionStatus.expired:
        return 'Suscripción vencida';
      case SubscriptionStatus.cancelled:
        return 'Suscripción cancelada';
      case SubscriptionStatus.active:
        return 'Suscripción activa';
      default:
        return 'Sin acceso';
    }
  }

  String _messageForStatus(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.pending:
        return 'Tu cuenta está pendiente de activación por el administrador.';
      case SubscriptionStatus.expired:
        return 'Tu suscripción ha vencido.\n\nContactá con el administrador para renovar.';
      case SubscriptionStatus.cancelled:
        return 'Tu suscripción fue cancelada.\n\nContactá con el administrador.';
      case SubscriptionStatus.active:
        return 'Tu suscripción está activa.';
      default:
        return 'Contactá con el administrador.';
    }
  }

  String _buttonLabel(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return 'CONTINUAR';
      default:
        return 'CERRAR SESIÓN';
    }
  }

  IconData _iconForStatus(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.pending:
        return Icons.hourglass_empty;
      case SubscriptionStatus.expired:
        return Icons.event_busy;
      case SubscriptionStatus.cancelled:
        return Icons.block;
      case SubscriptionStatus.active:
        return Icons.check_circle_outline;
      default:
        return Icons.lock_outline;
    }
  }

  Color _iconColor(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.pending:
        return AppColors.warning;
      case SubscriptionStatus.expired:
        return AppColors.negative;
      case SubscriptionStatus.cancelled:
        return AppColors.negative;
      case SubscriptionStatus.active:
        return AppColors.positive;
      default:
        return Colors.grey;
    }
  }
}
