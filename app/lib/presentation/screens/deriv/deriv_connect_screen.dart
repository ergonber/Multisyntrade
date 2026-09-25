import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_colors.dart';
import '../../../data/datasources/remote/deriv/deriv_oauth_service.dart';
import '../../../presentation/providers/deriv_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';

class DerivConnectScreen extends StatefulWidget {
  const DerivConnectScreen({super.key});

  @override
  State<DerivConnectScreen> createState() => _DerivConnectScreenState();
}

class _DerivConnectScreenState extends State<DerivConnectScreen> {
  final DerivOAuthService _oauthService = DerivOAuthService();
  final SupabaseClient _client = Supabase.instance.client;
  bool _isConnected = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final connected = await _oauthService.isConnected();
    final accountId = await _oauthService.getAccountId();
    if (mounted) {
      setState(() {
        _isConnected = connected;
        _accountId = accountId;
        _isLoading = false;
      });
    }
  }

  Future<void> _startOAuth() async {
    if (mounted) setState(() => _isProcessing = true);

    try {
      // Determine redirect target based on platform
      final redirectTarget = kIsWeb
          ? 'https://multisyntrade.vercel.app/deriv-callback'
          : 'syntrade://deriv-callback';

      // Call Edge Function to get auth URL (client_id stays in backend)
      final res = await _client.functions.invoke(
        'deriv-auth-start',
        body: {'redirect_target': redirectTarget},
      );

      if (res.status != 200) {
        throw Exception(res.data?['error'] ?? 'Error al iniciar conexión');
      }

      final authUrl = res.data['auth_url'] as String;
      debugPrint('[DerivConnect] OAuth URL: $authUrl');

      // platformDefault: on web opens in browser tab, on mobile opens external browser
      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir: $authUrl'),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    } catch (e) {
      debugPrint('[DerivConnect] OAuth start error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al conectar: $e'),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Desconectar Deriv'),
        content: const Text('Se perdera la conexion con tu cuenta de Deriv.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desconectar', style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _client.rpc('disconnect_deriv');
      if (mounted) {
        setState(() { _isConnected = false; _accountId = null; });
        context.read<DerivProvider>().disconnect();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deriv desconectado'),
            backgroundColor: AppColors.negative,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deriv = context.watch<DerivProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Conexion Deriv')),
      body: (_isLoading || _isProcessing)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isProcessing ? 'Abriendo Deriv...' : 'Verificando estado...',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _isConnected
                                ? AppColors.positive.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isConnected ? Icons.check_circle : Icons.account_balance_wallet_outlined,
                            color: _isConnected ? AppColors.positive : Colors.grey,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isConnected ? 'Cuenta Conectada' : 'Sin Conexion',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isConnected
                              ? 'Cuenta: ${_accountId ?? "Desconocida"}'
                              : 'Conecta tu cuenta de Deriv para recibir y ejecutar senales automaticamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!_isConnected) ...[
                    AppButton(
                      label: 'CONECTAR CON DERIV',
                      icon: Icons.open_in_new,
                      onPressed: _startOAuth,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                              const SizedBox(width: 8),
                              Text('Como funciona?',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Solo necesitas una cuenta en Deriv. Al conectar, autorizas a SynTrade a ejecutar trades en tu cuenta.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse('https://app.deriv.com/signup');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.platformDefault);
                              }
                            },
                            child: const Text(
                              'Crear cuenta demo en Deriv',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: AppColors.positive, size: 20),
                              const SizedBox(width: 8),
                              const Text('Estado', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.positive.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('ACTIVA',
                                    style: TextStyle(color: AppColors.positive, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.speed, color: Colors.grey, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                deriv.isConnected ? 'WebSocket: Conectado' : 'WebSocket: Desconectado',
                                style: TextStyle(
                                  color: deriv.isConnected ? AppColors.positive : Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (deriv.account.balance > 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.account_balance_wallet, color: Colors.grey, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Balance: ${deriv.account.balance.toStringAsFixed(2)} ${deriv.account.currency}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'DESCONECTAR',
                      isOutlined: true,
                      backgroundColor: AppColors.negative,
                      onPressed: _disconnect,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
