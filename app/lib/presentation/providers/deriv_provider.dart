import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/repositories/deriv_repository.dart';

class DerivProvider extends ChangeNotifier {
  final DerivRepository _derivRepo = DerivRepository();

  DerivConnectionState _connectionState = DerivConnectionState.disconnected;
  final Map<String, DerivTickData> _latestTicks = {};
  DerivAccountData _account = DerivAccountData.empty();
  List<Map<String, dynamic>> _activeSymbols = [];
  StreamSubscription<DerivConnectionState>? _stateSubscription;
  StreamSubscription<DerivTickData>? _tickSubscription;
  StreamSubscription<DerivAccountData>? _accountSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _symbolsSubscription;

  DerivConnectionState get connectionState => _connectionState;
  Map<String, DerivTickData> get latestTicks => Map.unmodifiable(_latestTicks);
  DerivAccountData get account => _account;
  List<Map<String, dynamic>> get activeSymbols => _activeSymbols;
  bool get isConnected => _connectionState == DerivConnectionState.connected;

  void init() {
    _stateSubscription = _derivRepo.stateStream.listen((state) {
      _connectionState = state;
      notifyListeners();
    });

    _tickSubscription = _derivRepo.tickStream.listen((tick) {
      _latestTicks[tick.symbol] = tick;
      notifyListeners();
    });

    _accountSubscription = _derivRepo.accountStream.listen((account) {
      _account = account;
      notifyListeners();
    });

    _symbolsSubscription = _derivRepo.symbolsStream.listen((symbols) {
      _activeSymbols = symbols;
      notifyListeners();
    });

    _tryAutoConnect();
  }

  Future<void> _tryAutoConnect() async {
    try {
      final hasToken = await _derivRepo.oauthService.getAccessToken() != null;
      if (hasToken) {
        await connect();
      }
    } catch (_) {}
  }

  Future<void> connect() async {
    try {
      await _derivRepo.connect();
    } catch (e) {
      _connectionState = DerivConnectionState.error;
      notifyListeners();
    }
  }

  void disconnect() {
    _derivRepo.disconnect();
  }

  /// Refresh connection status after deep link callback
  Future<void> refreshConnectionStatus() async {
    try {
      final hasToken = await _derivRepo.oauthService.getAccessToken() != null;
      if (hasToken && !isConnected) {
        await connect();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[DerivProvider] Refresh error: $e');
    }
  }

  void subscribeToSymbol(String symbol) {
    _derivRepo.subscribeTicks(symbol);
  }

  void getProposal({
    required String contractType,
    required String symbol,
    required double amount,
    required int duration,
    required String durationUnit,
    int multiplier = 1,
  }) {
    _derivRepo.getProposal(
      contractType: contractType,
      underlyingSymbol: symbol,
      amount: amount,
      duration: duration,
      durationUnit: durationUnit,
      multiplier: multiplier,
    );
  }

  void buyContract(String proposalId, double price) {
    _derivRepo.buyContract(proposalId, price);
  }

  double? getCurrentPrice(String symbol) {
    return _latestTicks[symbol]?.price;
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _tickSubscription?.cancel();
    _accountSubscription?.cancel();
    _symbolsSubscription?.cancel();
    _derivRepo.dispose();
    super.dispose();
  }
}
