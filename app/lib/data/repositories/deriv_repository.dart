import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../datasources/remote/deriv/deriv_oauth_service.dart';
import '../../core/errors/app_exception.dart';

enum DerivConnectionState { disconnected, connecting, connected, error }

class DerivTickData {
  final String symbol;
  final double price;
  const DerivTickData({required this.symbol, required this.price});
}

class DerivAccountData {
  final String loginid;
  final double balance;
  final String currency;
  const DerivAccountData({required this.loginid, required this.balance, required this.currency});
  factory DerivAccountData.empty() => const DerivAccountData(loginid: '', balance: 0, currency: 'USD');
}

class DerivRepository {
  final DerivOAuthService oauthService = DerivOAuthService();
  final SupabaseClient _client = Supabase.instance.client;

  WebSocketChannel? _channel;
  final StreamController<DerivTickData> _tickController =
      StreamController<DerivTickData>.broadcast();
  final StreamController<DerivConnectionState> _stateController =
      StreamController<DerivConnectionState>.broadcast();
  final StreamController<DerivAccountData> _accountController =
      StreamController<DerivAccountData>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _symbolsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<Map<String, dynamic>> _proposalController =
      StreamController<Map<String, dynamic>>.broadcast();

  DerivConnectionState _state = DerivConnectionState.disconnected;
  int _requestId = 0;
  String? _accessToken;
  String? _accountId;
  bool _autoReconnect = true;
  Timer? _pingTimer;
  Timer? _authTimeoutTimer;

  Stream<DerivTickData> get tickStream => _tickController.stream;
  Stream<DerivConnectionState> get stateStream => _stateController.stream;
  Stream<DerivAccountData> get accountStream => _accountController.stream;
  Stream<List<Map<String, dynamic>>> get symbolsStream => _symbolsController.stream;
  Stream<Map<String, dynamic>> get proposalStream => _proposalController.stream;
  DerivConnectionState get currentState => _state;
  bool get isConnected => _state == DerivConnectionState.connected;

  /// Connect using OTP-based WebSocket (new Deriv API flow)
  Future<void> connect() async {
    if (_state == DerivConnectionState.connecting) return;
    _updateState(DerivConnectionState.connecting);

    try {
      // Step 1: Get access token (with auto-refresh if expired)
      _accessToken = await oauthService.getAccessToken();
      if (_accessToken == null) {
        throw DerivConnectionException(message: 'No hay token. Conecta Deriv primero.');
      }

      _accountId = await oauthService.getAccountId();
      debugPrint('[Deriv] Token found, account=$_accountId');

      // Step 2: Get OTP WebSocket URL via Edge Function
      final otpResponse = await _client.functions.invoke('deriv-get-otp-url');

      if (otpResponse.status != 200) {
        final error = otpResponse.data;
        throw DerivConnectionException(
          message: error?['details'] ?? error?['error'] ?? 'Failed to get OTP URL',
        );
      }

      final otpData = otpResponse.data as Map<String, dynamic>;
      final wsUrl = otpData['ws_url'] as String?;

      if (wsUrl == null || wsUrl.isEmpty) {
        throw DerivConnectionException(message: 'No OTP WebSocket URL received');
      }

      debugPrint('[Deriv] Connecting to OTP URL: $wsUrl');

      // Step 3: Connect to WebSocket using OTP URL (no need to send authorize)
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        _onMessage,
        onDone: () {
          debugPrint('[Deriv] WS closed');
          _onDisconnected();
        },
        onError: (error) {
          debugPrint('[Deriv] WS error: $error');
          _updateState(DerivConnectionState.error);
        },
      );

      // Wait for connection to open
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 4: Subscribe to balance and symbols after connection
      // OTP handles authentication - no need to send authorize
      debugPrint('[Deriv] Subscribing to balance and symbols...');
      _sendRequest({'balance': 1, 'subscribe': 1});
      _sendRequest({'active_symbols': 'brief', 'product_type': 'basic'});

      // Set connection timeout - if no balance response in 5s, fail
      _authTimeoutTimer?.cancel();
      _authTimeoutTimer = Timer(const Duration(seconds: 5), () {
        if (_state == DerivConnectionState.connecting) {
          debugPrint('[Deriv] Connection timeout - no response');
          _updateState(DerivConnectionState.error);
          disconnect();
        }
      });

      // Keepalive ping every 30s
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _sendRequest({'ping': 1});
      });

    } catch (e) {
      debugPrint('[Deriv] Connect failed: $e');
      _updateState(DerivConnectionState.error);
      if (e is DerivConnectionException) rethrow;
      throw DerivConnectionException(message: 'Error de conexion: $e');
    }
  }

  /// Disconnect
  void disconnect() {
    _autoReconnect = false;
    _pingTimer?.cancel();
    _authTimeoutTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _accessToken = null;
    _accountId = null;
    _updateState(DerivConnectionState.disconnected);
  }

  /// Subscribe to ticks for a symbol
  void subscribeTicks(String symbol) {
    _sendRequest({'ticks': symbol, 'subscribe': 1});
  }

  /// Get price proposal
  void getProposal({
    required String contractType,
    required String underlyingSymbol,
    required double amount,
    required int duration,
    required String durationUnit,
    int multiplier = 1,
    String basis = 'stake',
    String currency = 'USD',
  }) {
    _sendRequest({
      'proposal': 1,
      'amount': amount,
      'basis': basis,
      'contract_type': contractType,
      'currency': currency,
      'duration': duration,
      'duration_unit': durationUnit,
      'multiplier': multiplier,
      'underlying_symbol': underlyingSymbol,
      'subscribe': 1,
    });
  }

  /// Buy contract
  void buyContract(String proposalId, double price) {
    _sendRequest({'buy': proposalId, 'price': price});
  }

  /// Sell contract
  void sellContract(String contractId, double price) {
    _sendRequest({'sell': contractId, 'price': price});
  }

  /// Monitor contract
  void monitorContract(String contractId) {
    _sendRequest({
      'proposal_open_contract': 1,
      'contract_id': contractId,
      'subscribe': 1,
    });
  }

  /// Get portfolio
  void getPortfolio() {
    _sendRequest({'portfolio': 1});
  }

  // --- Private helpers ---

  int _nextReqId() => ++_requestId;

  void _sendRequest(Map<String, dynamic> request) {
    if (_channel == null) return;
    request['req_id'] = _nextReqId();
    final msg = jsonEncode(request);
    debugPrint('[Deriv] >>> $msg');
    _channel!.sink.add(msg);
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final msgType = data['msg_type'];
      debugPrint('[Deriv] <<< msg_type=$msgType');

      switch (msgType) {
        case 'authorize':
          // Legacy flow - should not happen with OTP
          final authorize = data['authorize'];
          if (authorize != null && authorize['loginid'] != null) {
            _authTimeoutTimer?.cancel();
            _accountId = authorize['loginid'];
            debugPrint('[Deriv] Authorized: ${authorize["loginid"]}, balance=${authorize["balance"]}');
            _updateState(DerivConnectionState.connected);

            _sendRequest({'balance': 1, 'subscribe': 1});
            _sendRequest({'active_symbols': 'brief', 'product_type': 'basic'});

            _pingTimer?.cancel();
            _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
              _sendRequest({'ping': 1});
            });
          } else {
            debugPrint('[Deriv] Auth failed: ${data['error']}');
            _updateState(DerivConnectionState.error);
            disconnect();
          }
          break;

        case 'balance':
          final balance = data['balance'];
          // First balance response = connection confirmed (OTP flow)
          if (_state == DerivConnectionState.connecting) {
            _authTimeoutTimer?.cancel();
            _updateState(DerivConnectionState.connected);
          }
          _accountController.add(DerivAccountData(
            loginid: balance['loginid'] ?? _accountId ?? '',
            balance: (balance['balance'] ?? 0).toDouble(),
            currency: balance['currency'] ?? 'USD',
          ));
          break;

        case 'active_symbols':
          final symbols = data['active_symbols'] as List?;
          _symbolsController.add(symbols?.cast<Map<String, dynamic>>() ?? []);
          break;

        case 'tick':
          final tick = data['tick'];
          _tickController.add(DerivTickData(
            symbol: tick['symbol'] ?? '',
            price: (tick['quote'] ?? 0).toDouble(),
          ));
          break;

        case 'proposal':
          _proposalController.add(data['proposal'] ?? {});
          break;

        case 'buy':
          final contract = data['buy'];
          debugPrint('[Deriv] Contract bought: ${contract?['contract_id']}');
          break;

        case 'sell':
          debugPrint('[Deriv] Contract sold');

        case 'proposal_open_contract':
          final contract = data['proposal_open_contract'];
          debugPrint('[Deriv] Contract status: ${contract?['status']}');
          break;

        case 'pong':
          break;

        case 'error':
          final error = data['error'];
          debugPrint('[Deriv] Error: ${error?['message']} (code: ${error?["code"]})');
          break;

        default:
          debugPrint('[Deriv] Unknown msg_type: $msgType');
      }
    } catch (e) {
      debugPrint('[Deriv] Parse error: $e');
    }
  }

  void _onDisconnected() {
    debugPrint('[Deriv] WS disconnected');
    _pingTimer?.cancel();
    if (_state == DerivConnectionState.connected) {
      _updateState(DerivConnectionState.disconnected);
    }
    if (_autoReconnect && _state != DerivConnectionState.connecting) {
      Future.delayed(const Duration(seconds: 5), () {
        if (_autoReconnect && _state == DerivConnectionState.disconnected) {
          connect();
        }
      });
    }
  }

  void _updateState(DerivConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    disconnect();
    _tickController.close();
    _stateController.close();
    _accountController.close();
    _symbolsController.close();
    _proposalController.close();
  }
}
