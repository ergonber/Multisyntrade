import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../providers/admin/admin_signals_provider.dart';

class NewSignalScreen extends StatefulWidget {
  const NewSignalScreen({super.key});

  @override
  State<NewSignalScreen> createState() => _NewSignalScreenState();
}

class _NewSignalScreenState extends State<NewSignalScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedActivo;
  String _direccion = 'compra';
  double? _riesgoRecomendado;
  double? _selectedMultiplicador;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminSignalsProvider>();
      provider.load();
      // Refresca el catálogo de Deriv en segundo plano (no bloquea el formulario)
      provider.syncActivos();
    });
  }

  List<double> get _availableMultiplicadores {
    if (_selectedActivo == null) return [];
    final provider = context.read<AdminSignalsProvider>();
    final activo = provider.activos.firstWhere(
      (a) => a.derivSymbol == _selectedActivo,
      orElse: () => provider.activos.first,
    );
    return activo.multiplicadores;
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedActivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un activo'), backgroundColor: AppColors.negative),
      );
      return;
    }
    if (_selectedMultiplicador == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un multiplicador'), backgroundColor: AppColors.negative),
      );
      return;
    }

    final provider = context.read<AdminSignalsProvider>();
    final activo = provider.activos.firstWhere(
      (a) => a.derivSymbol == _selectedActivo,
      orElse: () => provider.activos.first,
    );

    final ventanaId = await provider.createVentana(
      activoId: activo.id,
      derivSymbol: _selectedActivo!,
      tipo: activo.isBoom ? 'boom' : activo.isCrash ? 'crash' : 'volatility',
      direccion: _direccion,
      fechaInicio: DateTime.now().add(const Duration(minutes: 2)),
      multiplicador: _selectedMultiplicador!,
      riesgoRecomendado: _riesgoRecomendado,
    );

    if (ventanaId == null) {
      if (mounted && provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error!), backgroundColor: AppColors.negative),
        );
      }
      return;
    }

    // Publish + fire-and-forget execution
    final result = await provider.publishAndExecute(ventanaId);

    if (mounted && provider.error == null && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Señal creada. Ejecutando en segundo plano.'),
          backgroundColor: AppColors.positive,
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.pop(context);
    } else if (mounted && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: AppColors.negative),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminSignalsProvider>();
    final activos = provider.activos;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Señal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('ACTIVO',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButton<String>(
                  value: _selectedActivo,
                  hint: const Text('Seleccionar activo', style: TextStyle(color: Colors.grey)),
                  isExpanded: true,
                  dropdownColor: AppColors.card,
                  underline: const SizedBox(),
                  items: activos.map((a) => DropdownMenuItem(
                    value: a.derivSymbol,
                    child: Text('${a.nombre} (${a.derivSymbol})'),
                  )).toList(),
                  onChanged: (v) => setState(() {
                    _selectedActivo = v;
                    _selectedMultiplicador = null;
                  }),
                ),
              ),
              const SizedBox(height: 24),
              const Text('DIRECCIÓN',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildDirectionButton('compra', 'ALZA', AppColors.positive, Icons.trending_up)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDirectionButton('venta', 'BAJA', AppColors.negative, Icons.trending_down)),
                ],
              ),
              const SizedBox(height: 24),
              const Text('MULTIPLICADOR',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              if (_selectedActivo == null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('Primero selecciona un activo',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButton<double>(
                    value: _selectedMultiplicador,
                    hint: const Text('Seleccionar multiplicador', style: TextStyle(color: Colors.grey)),
                    isExpanded: true,
                    dropdownColor: AppColors.card,
                    underline: const SizedBox(),
                    items: _availableMultiplicadores.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text('x${m.toInt()}'),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedMultiplicador = v),
                  ),
                ),
              const SizedBox(height: 24),
              const Text('RIESGO RECOMENDADO (OPCIONAL)',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: AppColors.border,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: Slider(
                  value: _riesgoRecomendado ?? 5,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${(_riesgoRecomendado ?? 5).round()}',
                  onChanged: (v) => setState(() => _riesgoRecomendado = v),
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'CREAR Y PUBLICAR',
                isLoading: provider.isLoading,
                onPressed: _publish,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionButton(String value, String label, Color color, IconData icon) {
    final isSelected = _direccion == value;
    return GestureDetector(
      onTap: () => setState(() => _direccion = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? color : Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
