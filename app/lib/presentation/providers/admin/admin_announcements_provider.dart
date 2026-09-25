import 'package:flutter/material.dart';
import '../../../data/repositories/admin/admin_announcements_repository.dart';
import '../../../data/models/announcement_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminAnnouncementsProvider extends ChangeNotifier {
  final AdminAnnouncementsRepository _repo = AdminAnnouncementsRepository();

  List<AnnouncementModel> _announcements = [];
  bool _isLoading = false;
  String? _error;

  List<AnnouncementModel> get announcements => _announcements;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _announcements = await _repo.getAll();
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error al cargar anuncios';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> create({
    required String titulo,
    required String cuerpo,
    String? imageUrl,
    bool activo = true,
  }) async {
    try {
      await _repo.create(titulo: titulo, cuerpo: cuerpo, imageUrl: imageUrl, activo: activo);
      await load();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> update({
    required String id,
    String? titulo,
    String? cuerpo,
    String? imageUrl,
    bool? activo,
  }) async {
    try {
      await _repo.update(id: id, titulo: titulo, cuerpo: cuerpo, imageUrl: imageUrl, activo: activo);
      await load();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repo.delete(id);
      await load();
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
