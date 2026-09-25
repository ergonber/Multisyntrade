import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/utils/validators.dart';
import '../../providers/goals_provider.dart';

class CrearMetaScreen extends StatefulWidget {
  const CrearMetaScreen({super.key});

  @override
  State<CrearMetaScreen> createState() => _CrearMetaScreenState();
}

class _CrearMetaScreenState extends State<CrearMetaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _montoController = TextEditingController();

  @override
  void dispose() {
    _nombreController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final goals = context.read<GoalsProvider>();
    await goals.createMeta(
      objetivo: _nombreController.text.trim(),
      montoMeta: double.parse(_montoController.text),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final goals = context.watch<GoalsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Objetivo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              AppInput(
                controller: _nombreController,
                labelText: 'NOMBRE DEL OBJETIVO',
                hintText: 'Ej. Comprar mi casa',
                prefixIcon: Icons.flag_outlined,
                validator: (v) => Validators.required(v, 'el nombre'),
              ),
              const SizedBox(height: 24),
              AppInput(
                controller: _montoController,
                labelText: 'MONTO OBJETIVO',
                hintText: '10000',
                prefixIcon: Icons.attach_money,
                keyboardType: TextInputType.number,
                validator: Validators.capital,
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'CREAR OBJETIVO',
                isLoading: goals.isLoading,
                onPressed: _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
