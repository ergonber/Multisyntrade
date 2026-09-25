class OperationModel {
  final String id;
  final String? ventanaId;
  final String? userId;
  final String? userName;
  final String? activo;
  final String? derivSymbol;
  final String? tipo;
  final String? direccion;
  final int? multiplicador;
  final double? monto;
  final String estado;
  final double? resultado;
  final DateTime? createdAt;

  const OperationModel({
    required this.id,
    this.ventanaId,
    this.userId,
    this.userName,
    this.activo,
    this.derivSymbol,
    this.tipo,
    this.direccion,
    this.multiplicador,
    this.monto,
    this.estado = 'en_curso',
    this.resultado,
    this.createdAt,
  });

  bool get isWin => estado == 'ganada';
  bool get isLoss => estado == 'perdida';
  bool get isEnCurso => estado == 'en_curso';
  bool get isRechazada => estado == 'rechazada';
  bool get isCancelada => estado == 'cancelada';

  String get estadoLabel {
    switch (estado) {
      case 'en_curso':
        return 'En curso';
      case 'ganada':
        return 'Ganada';
      case 'perdida':
        return 'Perdida';
      case 'rechazada':
        return 'Rechazada';
      case 'cancelada':
        return 'Cancelada';
      default:
        return estado;
    }
  }

  factory OperationModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    final mult = map['multiplicador'];
    return OperationModel(
      id: map['id'] ?? '',
      ventanaId: map['ventana_id'],
      userId: map['user_id'],
      userName: profile?['nombre'] ?? profile?['email'],
      activo: map['activo'],
      derivSymbol: map['deriv_symbol'],
      tipo: map['tipo'],
      direccion: map['direccion'],
      multiplicador: mult is num ? mult.toInt() : null,
      monto: (map['monto'] ?? 0).toDouble(),
      estado: map['estado'] ?? 'en_curso',
      resultado: map['resultado']?.toDouble(),
      createdAt: (map['creado_en'] ?? map['created_at']) != null
          ? DateTime.parse((map['creado_en'] ?? map['created_at']))
          : null,
    );
  }
}
