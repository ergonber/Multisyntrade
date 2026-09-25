import 'package:flutter/material.dart';

class SimulatorProvider extends ChangeNotifier {
  double _capital = 1000;
  double _riskPercent = 3.0;
  int _cycleHours = 24;
  int _totalOperations = 24;
  int _wins = 18;
  bool _isSimulating = false;

  double get capital => _capital;
  double get riskPercent => _riskPercent;
  int get cycleHours => _cycleHours;
  int get totalOperations => _totalOperations;
  int get wins => _wins;
  bool get isSimulating => _isSimulating;

  int get losses => _totalOperations - _wins;
  double get winRate => _totalOperations > 0 ? (_wins / _totalOperations) * 100 : 0;
  double get riskAmount => _capital * (_riskPercent / 100);

  double get estimatedProfit {
    double total = 0;
    for (int i = 0; i < _totalOperations; i++) {
      if (i < _wins) {
        total += riskAmount * 1.5;
      } else {
        total -= riskAmount;
      }
    }
    return total;
  }

  double get projectedROI => _capital > 0 ? (estimatedProfit / _capital) * 100 : 0;

  double get finalCapital => _capital + estimatedProfit;

  void setCapital(double value) {
    _capital = value;
    notifyListeners();
  }

  void setRiskPercent(double value) {
    _riskPercent = value;
    notifyListeners();
  }

  void setCycleHours(int value) {
    _cycleHours = value;
    notifyListeners();
  }

  void setOperations(int wins, int total) {
    _wins = wins;
    _totalOperations = total;
    notifyListeners();
  }

  Future<void> runSimulation() async {
    _isSimulating = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 2));
    _isSimulating = false;
    notifyListeners();
  }
}
