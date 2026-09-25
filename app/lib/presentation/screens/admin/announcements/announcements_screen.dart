import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../config/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_input.dart';
import '../../../../core/utils/validators.dart';
import '../../../providers/admin/admin_announcements_provider.dart';
import '../widgets/admin_empty_state.dart';
import '../widgets/admin_loading.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _tituloController = TextEditingController();
  final _cuerpoController = TextEditingController();
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminAnnouncementsProvider>().load();
    });
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _cuerpoController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_tituloController.text.isEmpty || _cuerpoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa título y cuerpo'), backgroundColor: AppColors.negative),
      );
      return;
    }

    final provider = context.read<AdminAnnouncementsProvider>();
    await provider.create(
      titulo: _tituloController.text.trim(),
      cuerpo: _cuerpoController.text.trim(),
    );

    if (mounted && provider.error == null) {
      _tituloController.clear();
      _cuerpoController.clear();
      setState(() => _showForm = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anuncio creado'), backgroundColor: AppColors.positive),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminAnnouncementsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anuncios'),
        actions: [
          IconButton(
            icon: Icon(_showForm ? Icons.close : Icons.add),
            onPressed: () => setState(() => _showForm = !_showForm),
          ),
        ],
      ),
      body: provider.isLoading && provider.announcements.isEmpty
          ? const AdminLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showForm) _buildForm(),
                  if (provider.announcements.isEmpty)
                    const AdminEmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'No hay anuncios',
                      subtitle: 'Crea el primer anuncio para los usuarios',
                    )
                  else
                    ...provider.announcements.map((a) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: a.activo ? AppColors.positive.withValues(alpha: 0.15) : AppColors.negative.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  a.activo ? 'Activo' : 'Inactivo',
                                  style: TextStyle(
                                    color: a.activo ? AppColors.positive : AppColors.negative,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(a.body ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => provider.update(id: a.id, activo: !a.activo),
                                child: Text(
                                  a.activo ? 'Desactivar' : 'Activar',
                                  style: TextStyle(color: AppColors.primary, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () => provider.delete(a.id),
                                child: const Text('Eliminar', style: TextStyle(color: AppColors.negative, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )),
                ],
              ),
            ),
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nuevo Anuncio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          AppInput(
            controller: _tituloController,
            labelText: 'TÍTULO',
            hintText: 'Título del anuncio',
            prefixIcon: Icons.title,
            validator: (v) => Validators.required(v, 'el título'),
          ),
          const SizedBox(height: 16),
          AppInput(
            controller: _cuerpoController,
            labelText: 'CUERPO',
            hintText: 'Contenido del anuncio',
            maxLines: 3,
            validator: (v) => Validators.required(v, 'el cuerpo'),
          ),
          const SizedBox(height: 16),
          AppButton(label: 'CREAR ANUNCIO', onPressed: _create),
        ],
      ),
    );
  }
}
