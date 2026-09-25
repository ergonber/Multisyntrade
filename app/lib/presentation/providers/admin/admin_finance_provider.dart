import 'package:flutter/material.dart';
import '../../../data/repositories/admin/admin_finance_repository.dart';
import '../../../data/models/admin/finance_summary_model.dart';
import '../../../core/errors/app_exception.dart';

class AdminFinanceProvider extends ChangeNotifier {
  final AdminFinanceRepository _repo = AdminFinanceRepository();

  FinanceSummaryModel _summary = const FinanceSummaryModel();
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = false;
  String? _error;

  FinanceSummaryModel get summary => _summary;
  List<Map<String, dynamic>> get payments => _payments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repo.getSummary(),
        _repo.getPayments(),
      ]);
      _summary = results[0] as FinanceSummaryModel;
      _payments = results[1] as List<Map<String, dynamic>>;
    } on AppException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Error al cargar finanzas';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
