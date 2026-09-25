import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class CapitalRiskScreen extends StatefulWidget {
  const CapitalRiskScreen({super.key});

  @override
  State<CapitalRiskScreen> createState() => _CapitalRiskScreenState();
}

class _CapitalRiskScreenState extends State<CapitalRiskScreen> {
  final _capitalController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double _riskPct = 2.0;

  static const _riskOptions = [1.0, 2.0, 3.0, 4.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<ProfileProvider>().profile;
      if (profile != null) {
        _capitalController.text = profile.capitalInicial > 0
            ? profile.capitalInicial.toStringAsFixed(2)
            : '';
        _riskPct = profile.riskPercentage > 0 ? profile.riskPercentage : 2.0;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _capitalController.dispose();
    super.dispose();
  }

  double get _riskAmount {
    final cap = double.tryParse(_capitalController.text) ?? 0;
    return cap * _riskPct / 100;
  }

  Future<void> _onRiskSelected(double value) async {
    if (value > 5) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Alto riesgo'),
          content: Text(
            'Con ${value.toInt()}% de riesgo, diez operaciones perdedoras '
            'seguidas consumen tu capital. ¿Confirmás?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar', style: TextStyle(color: AppColors.warning)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _riskPct = value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final userId = auth.currentUser?.id;
    if (userId == null) return;

    final capital = double.tryParse(_capitalController.text) ?? 0;

    profileProvider.clearError();
    await profileProvider.setCapital(userId, capital);
    await profileProvider.setRisk(userId, _riskPct);

    if (mounted) {
      if (profileProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(profileProvider.error!),
            backgroundColor: AppColors.negative,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Capital y riesgo guardados.'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final isLoading = profileProvider.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Capital y Riesgo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CAPITAL INICIAL',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _capitalController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.grey[700]),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresá tu capital';
                  final n = double.tryParse(v);
                  if (n == null) return 'Número inválido';
                  if (n <= 0) return 'El capital debe ser mayor a 0';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Este dato lo declarás vos. SynTrade no lo verifica.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 32),
              const Text('PORCENTAJE DE RIESGO',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _riskOptions.map((pct) {
                  final isSelected = _riskPct == pct;
                  return GestureDetector(
                    onTap: () => _onRiskSelected(pct),
                    child: Container(
                      width: 64,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (pct > 5 ? AppColors.warning : AppColors.primary).withOpacity(0.15)
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? (pct > 5 ? AppColors.warning : AppColors.primary)
                              : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${pct.toInt()}%',
                          style: TextStyle(
                            color: isSelected
                                ? (pct > 5 ? AppColors.warning : AppColors.primary)
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    Text(
                      'Con este perfil arriesgás',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${_riskAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'por operación',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'GUARDAR',
                isLoading: isLoading,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
