import 'package:flutter/material.dart';
import '../../../data/repositories/admin/admin_operations_repository.dart';
import '../../../data/models/admin/operation_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminOperationsProvider extends ChangeNotifier {
  final AdminOperationsRepository _repo = AdminOperationsRepository();

  List<OperationModel> _operations = [];
  String? _filterEstado;
  bool _isLoading = false;
  String? _error;

  List<OperationModel> get operations => _operations;
  String? get filterEstado => _filterEstado;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<OperationModel> get filtered => _filterEstado == null
      ? _operations
      : _operations.where((o) => o.estado == _filterEstado).toList();

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _operations = await _repo.getOperations(estado: _filterEstado);
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error al cargar operaciones';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String? estado) {
    _filterEstado = estado;
    load();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
