class OperationModel {
  final String id;
  final String? ventanaId;
  final String? userId;
  final String? activo;
  final String? derivSymbol;
  final String? tipo;
  final String? direccion;
  final int? multiplicador;
  final double? monto;
  final double? ganancia;
  final String estado;
  final String? resultado;
  final DateTime? createdAt;

  const OperationModel({
    required this.id,
    this.ventanaId,
    this.userId,
    this.activo,
    this.derivSymbol,
    this.tipo,
    this.direccion,
    this.multiplicador,
    this.monto,
    this.ganancia,
    this.estado = 'pendiente',
    this.resultado,
    this.createdAt,
  });

  bool get isWin => resultado == 'ganada';
  bool get isLoss => resultado == 'perdida';
  bool get isPending => estado == 'pendiente';
  bool get isExecuted => estado == 'ejecutada';

  factory OperationModel.fromMap(Map<String, dynamic> map) {
    return OperationModel(
      id: map['id'] ?? '',
      ventanaId: map['ventana_id'],
      userId: map['user_id'],
      activo: map['activo'],
      derivSymbol: map['deriv_symbol'],
      tipo: map['tipo'],
      direccion: map['direccion'],
      multiplicador: map['multiplicador'],
      monto: (map['monto'] ?? 0).toDouble(),
      ganancia: map['ganancia']?.toDouble(),
      estado: map['estado'] ?? 'pendiente',
      resultado: map['resultado'],
      createdAt: (map['creado_en'] ?? map['created_at']) != null
          ? DateTime.parse((map['creado_en'] ?? map['created_at']))
          : null,
    );
  }
}
