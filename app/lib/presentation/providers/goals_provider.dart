import 'package:flutter/material.dart';
import '../../data/repositories/metas_repository.dart';
import '../../data/models/meta_model.dart';
import '../../core/errors/app_exception.dart';

class GoalsProvider extends ChangeNotifier {
  final MetasRepository _metasRepo = MetasRepository();

  List<MetaModel> _metas = [];
  bool _isLoading = false;
  String? _error;

  List<MetaModel> get metas => _metas;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<MetaModel> get activeMetas => _metas.where((m) => m.isInProgress).toList();
  List<MetaModel> get completedMetas => _metas.where((m) => m.isCompleted).toList();

  double get totalProgress {
    if (_metas.isEmpty) return 0;
    final total = _metas.fold(0.0, (sum, m) => sum + m.progressPercent);
    return total / _metas.length;
  }

  Future<void> loadMetas() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _metas = await _metasRepo.getMyMetas();
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error al cargar metas';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createMeta({
    required String objetivo,
    required double montoMeta,
    String? descripcion,
    String? imagenUrl,
  }) async {
    try {
      await _metasRepo.createMeta(
        objetivo: objetivo,
        montoMeta: montoMeta,
        descripcion: descripcion,
        imagenUrl: imagenUrl,
      );
      await loadMetas();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> updateMeta(String metaId, Map<String, dynamic> data) async {
    try {
      await _metasRepo.updateMeta(metaId, data);
      await loadMetas();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> deleteMeta(String metaId) async {
    try {
      await _metasRepo.deleteMeta(metaId);
      await loadMetas();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
