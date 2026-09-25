class VentanaModel {
  final String id;
  final String? titulo;
  final String activoId;
  final String derivSymbol;
  final String tipo;
  final String direccion;
  final int duracionMinutos;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final String estado;
  final String? senalApertura;
  final String? senalCierre;
  final String? resultado;
  final double? riesgoRecomendado;
  final double? multiplicador;
  final DateTime createdAt;

  const VentanaModel({
    required this.id,
    this.titulo,
    required this.activoId,
    required this.derivSymbol,
    required this.tipo,
    required this.direccion,
    required this.duracionMinutos,
    required this.fechaInicio,
    this.fechaFin,
    required this.estado,
    this.senalApertura,
    this.senalCierre,
    this.resultado,
    this.riesgoRecomendado,
    this.multiplicador,
    required this.createdAt,
  });

  bool get isProgramada => estado == 'programada';
  bool get isActiva => estado == 'activa';
  bool get isCerrada => estado == 'cerrada';
  bool get isCancelada => estado == 'cancelada';
  bool get isCompra => direccion == 'compra';
  bool get isVenta => direccion == 'venta';
  bool get isGanada => resultado == 'ganada';
  bool get isPerdida => resultado == 'perdida';
  bool get isSinOperar => resultado == 'sin_operar';

  String get directionLabel => isCompra ? 'ALZA' : 'BAJA';
  String get estadoLabel {
    switch (estado) {
      case 'programada': return 'Programada';
      case 'activa': return 'Activa';
      case 'cerrada': return resultado == 'ganada' ? 'Ganada' : resultado == 'perdida' ? 'Perdida' : 'Cerrada';
      case 'cancelada': return 'Cancelada';
      default: return estado;
    }
  }

  VentanaModel copyWith({
    String? titulo,
    String? estado,
    String? senalApertura,
    String? senalCierre,
    String? resultado,
    DateTime? fechaFin,
  }) {
    return VentanaModel(
      id: id,
      titulo: titulo ?? this.titulo,
      activoId: activoId,
      derivSymbol: derivSymbol,
      tipo: tipo,
      direccion: direccion,
      duracionMinutos: duracionMinutos,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      estado: estado ?? this.estado,
      senalApertura: senalApertura ?? this.senalApertura,
      senalCierre: senalCierre ?? this.senalCierre,
      resultado: resultado ?? this.resultado,
      riesgoRecomendado: riesgoRecomendado,
      multiplicador: multiplicador,
      createdAt: createdAt,
    );
  }

  factory VentanaModel.fromMap(Map<String, dynamic> map) {
    return VentanaModel(
      id: map['id'] ?? '',
      titulo: map['titulo'],
      activoId: map['activo_id'] ?? '',
      derivSymbol: map['deriv_symbol'] ?? '',
      tipo: map['tipo'] ?? '',
      direccion: map['direccion'] ?? 'compra',
      duracionMinutos: map['duracion_minutos'] ?? 5,
      fechaInicio: DateTime.parse(map['fecha_inicio'] ?? DateTime.now().toIso8601String()),
      fechaFin: map['fecha_fin'] != null ? DateTime.parse(map['fecha_fin']) : null,
      estado: map['estado'] ?? 'programada',
      senalApertura: map['senal_apertura'],
      senalCierre: map['senal_cierre'],
      resultado: map['resultado'],
      riesgoRecomendado: map['riesgo_recomendado']?.toDouble(),
      multiplicador: map['multiplicador']?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'titulo': titulo,
    'activo_id': activoId,
    'deriv_symbol': derivSymbol,
    'tipo': tipo,
    'direccion': direccion,
    'duracion_minutos': duracionMinutos,
    'fecha_inicio': fechaInicio.toIso8601String(),
    'fecha_fin': fechaFin?.toIso8601String(),
    'estado': estado,
    'senal_apertura': senalApertura,
    'senal_cierre': senalCierre,
    'resultado': resultado,
    'riesgo_recomendado': riesgoRecomendado,
    'multiplicador': multiplicador,
    'created_at': createdAt.toIso8601String(),
  };
}
