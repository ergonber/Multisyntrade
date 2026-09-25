class TradeExecutionModel {
  final String id;
  final String userId;
  final String ventanaId;
  final String activo;
  final String derivSymbol;
  final double monto;
  final int multiplicador;
  final String? contractId;
  final String estado;
  final double? resultado;
  final String? executionId;
  final DateTime createdAt;

  const TradeExecutionModel({
    required this.id,
    required this.userId,
    required this.ventanaId,
    required this.activo,
    required this.derivSymbol,
    required this.monto,
    required this.multiplicador,
    this.contractId,
    required this.estado,
    this.resultado,
    this.executionId,
    required this.createdAt,
  });

  bool get isEnCurso => estado == 'en_curso';
  bool get isGanada => estado == 'ganada';
  bool get isPerdida => estado == 'perdida';
  bool get isRechazada => estado == 'rechazada';
  bool get isCancelada => estado == 'cancelada';

  bool get isPositive => resultado != null && resultado! > 0;
  bool get isNegative => resultado != null && resultado! < 0;

  double get profitPercent => monto > 0 && resultado != null ? (resultado! / monto) * 100 : 0;

  factory TradeExecutionModel.fromMap(Map<String, dynamic> map) {
    return TradeExecutionModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      ventanaId: map['ventana_id'] ?? '',
      activo: map['activo'] ?? '',
      derivSymbol: map['deriv_symbol'] ?? '',
      monto: (map['monto'] ?? 0).toDouble(),
      multiplicador: map['multiplicador'] ?? 1,
      contractId: map['contract_id'],
      estado: map['estado'] ?? 'en_curso',
      resultado: map['resultado']?.toDouble(),
      executionId: map['execution_id'],
      createdAt: DateTime.parse(map['creado_en'] ?? map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'ventana_id': ventanaId,
    'activo': activo,
    'deriv_symbol': derivSymbol,
    'monto': monto,
    'multiplicador': multiplicador,
    'contract_id': contractId,
    'estado': estado,
    'resultado': resultado,
    'execution_id': executionId,
  };
}
