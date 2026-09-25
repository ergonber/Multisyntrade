class ProfileModel {
  final String id;
  final String nombre;
  final String? telefono;
  final String? fotoUrl;
  final String rol;
  final String derivConnectionStatus;
  final double capitalInicial;
  final bool capitalInicialConfigurado;
  final double gananciaAcumulada;
  final double riskPercentage;
  final String? fcmToken;
  final String? deviceId;
  final DateTime? lastLoginAt;
  final bool notifNuevaOperacion;
  final bool notifResultado;
  final bool notifPromociones;
  final bool notifSistema;
  final bool notifObjetivos;
  final DateTime? createdAt;

  const ProfileModel({
    required this.id,
    required this.nombre,
    this.telefono,
    this.fotoUrl,
    this.rol = 'user',
    this.derivConnectionStatus = 'disconnected',
    this.capitalInicial = 0,
    this.capitalInicialConfigurado = false,
    this.gananciaAcumulada = 0,
    this.riskPercentage = 2.0,
    this.fcmToken,
    this.deviceId,
    this.lastLoginAt,
    this.notifNuevaOperacion = true,
    this.notifResultado = true,
    this.notifPromociones = true,
    this.notifSistema = true,
    this.notifObjetivos = true,
    this.createdAt,
  });

  bool get isAdmin => rol == 'admin';
  bool get isAnalyst => rol == 'analista';
  bool get isSupport => rol == 'soporte';
  bool get isUser => rol == 'user';
  bool get isDerivConnected => derivConnectionStatus == 'connected';
  bool get hasCapital => capitalInicialConfigurado && capitalInicial > 0;

  ProfileModel copyWith({
    String? nombre,
    String? telefono,
    String? fotoUrl,
    String? rol,
    String? derivConnectionStatus,
    double? capitalInicial,
    bool? capitalInicialConfigurado,
    double? gananciaAcumulada,
    double? riskPercentage,
    bool? notifNuevaOperacion,
    bool? notifResultado,
    bool? notifPromociones,
    bool? notifSistema,
    bool? notifObjetivos,
  }) {
    return ProfileModel(
      id: id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      rol: rol ?? this.rol,
      derivConnectionStatus: derivConnectionStatus ?? this.derivConnectionStatus,
      capitalInicial: capitalInicial ?? this.capitalInicial,
      capitalInicialConfigurado: capitalInicialConfigurado ?? this.capitalInicialConfigurado,
      gananciaAcumulada: gananciaAcumulada ?? this.gananciaAcumulada,
      riskPercentage: riskPercentage ?? this.riskPercentage,
      fcmToken: fcmToken,
      deviceId: deviceId,
      lastLoginAt: lastLoginAt,
      notifNuevaOperacion: notifNuevaOperacion ?? this.notifNuevaOperacion,
      notifResultado: notifResultado ?? this.notifResultado,
      notifPromociones: notifPromociones ?? this.notifPromociones,
      notifSistema: notifSistema ?? this.notifSistema,
      notifObjetivos: notifObjetivos ?? this.notifObjetivos,
      createdAt: createdAt,
    );
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'],
      fotoUrl: map['foto_url'],
      rol: map['rol'] ?? 'user',
      derivConnectionStatus: map['deriv_connection_status'] ?? 'desconectada',
      capitalInicial: (map['capital_inicial'] ?? 0).toDouble(),
      capitalInicialConfigurado: map['capital_inicial_configurado'] ?? false,
      gananciaAcumulada: (map['ganancia_acumulada'] ?? 0).toDouble(),
      riskPercentage: (map['risk_percentage'] ?? 2).toDouble(),
      fcmToken: map['fcm_token'],
      deviceId: map['device_id'],
      lastLoginAt: map['last_login_at'] != null ? DateTime.parse(map['last_login_at']) : null,
      notifNuevaOperacion: map['notif_nueva_operacion'] ?? true,
      notifResultado: map['notif_resultado'] ?? true,
      notifPromociones: map['notif_promociones'] ?? true,
      notifSistema: map['notif_sistema'] ?? true,
      notifObjetivos: map['notif_objetivos'] ?? true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'telefono': telefono,
    'foto_url': fotoUrl,
    'rol': rol,
    'deriv_connection_status': derivConnectionStatus,
    'capital_inicial': capitalInicial,
    'capital_inicial_configurado': capitalInicialConfigurado,
    'ganancia_acumulada': gananciaAcumulada,
    'risk_percentage': riskPercentage,
    'notif_nueva_operacion': notifNuevaOperacion,
    'notif_resultado': notifResultado,
    'notif_promociones': notifPromociones,
    'notif_sistema': notifSistema,
    'notif_objetivos': notifObjetivos,
  };

  Map<String, dynamic> toUpdateMap() => {
    'nombre': nombre,
    'telefono': telefono,
    'foto_url': fotoUrl,
    'deriv_connection_status': derivConnectionStatus,
    'capital_inicial': capitalInicial,
    'capital_inicial_configurado': capitalInicialConfigurado,
    'ganancia_acumulada': gananciaAcumulada,
    'risk_percentage': riskPercentage,
    'notif_nueva_operacion': notifNuevaOperacion,
    'notif_resultado': notifResultado,
    'notif_promociones': notifPromociones,
    'notif_sistema': notifSistema,
    'notif_objetivos': notifObjetivos,
  };
}
