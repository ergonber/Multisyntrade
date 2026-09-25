class MetaModel {
  final String id;
  final String userId;
  final String objetivo;
  final String? descripcion;
  final double montoMeta;
  final double progreso;
  final String estado;
  final String? imagenUrl;
  final DateTime createdAt;

  const MetaModel({
    required this.id,
    required this.userId,
    required this.objetivo,
    this.descripcion,
    required this.montoMeta,
    this.progreso = 0,
    this.estado = 'en_progreso',
    this.imagenUrl,
    required this.createdAt,
  });

  bool get isCompleted => estado == 'completada';
  bool get isInProgress => estado == 'en_progreso';
  bool get isCancelled => estado == 'cancelada';

  double get progressPercent => montoMeta > 0 ? (progreso / montoMeta) * 100 : 0;
  double get remaining => (montoMeta - progreso).clamp(0, montoMeta);

  String get estimatedCompletion {
    if (isCompleted) return 'Completado';
    if (progressPercent <= 0) return 'Sin progreso';
    return '${(remaining / (progreso > 0 ? progreso : 1)).ceil()} meses';
  }

  MetaModel copyWith({
    String? objetivo,
    String? descripcion,
    double? montoMeta,
    double? progreso,
    String? estado,
    String? imagenUrl,
  }) {
    return MetaModel(
      id: id,
      userId: userId,
      objetivo: objetivo ?? this.objetivo,
      descripcion: descripcion ?? this.descripcion,
      montoMeta: montoMeta ?? this.montoMeta,
      progreso: progreso ?? this.progreso,
      estado: estado ?? this.estado,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      createdAt: createdAt,
    );
  }

  factory MetaModel.fromMap(Map<String, dynamic> map) {
    return MetaModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      objetivo: map['objetivo'] ?? '',
      descripcion: map['descripcion'],
      montoMeta: (map['monto_meta'] ?? 0).toDouble(),
      progreso: (map['progreso'] ?? 0).toDouble(),
      estado: map['estado'] ?? 'en_progreso',
      imagenUrl: map['imagen_url'],
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'objetivo': objetivo,
    'descripcion': descripcion,
    'monto_meta': montoMeta,
    'progreso': progreso,
    'estado': estado,
    'imagen_url': imagenUrl,
  };
}
