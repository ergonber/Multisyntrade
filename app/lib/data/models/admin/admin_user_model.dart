class AdminUserModel {
  final String id;
  final String nombre;
  final String? email;
  final String? telefono;
  final String? fotoUrl;
  final String rol;
  final String derivConnectionStatus;
  final DateTime? createdAt;
  final String? plan;
  final String? subscriptionEstado;
  final DateTime? subscriptionFechaFin;

  const AdminUserModel({
    required this.id,
    required this.nombre,
    this.email,
    this.telefono,
    this.fotoUrl,
    this.rol = 'user',
    this.derivConnectionStatus = 'disconnected',
    this.createdAt,
    this.plan,
    this.subscriptionEstado,
    this.subscriptionFechaFin,
  });

  String get displayName => (email != null && email!.isNotEmpty) ? email! : nombre;
  String get initial => (displayName.isNotEmpty ? displayName[0] : '?').toUpperCase();

  bool get isAdmin => rol == 'admin';
  bool get isActive => subscriptionEstado == 'activa' &&
      subscriptionFechaFin != null &&
      subscriptionFechaFin!.isAfter(DateTime.now());
  bool get isPending => subscriptionEstado == 'pendiente';
  bool get isExpired => subscriptionEstado == 'vencida' ||
      (subscriptionEstado == 'activa' && subscriptionFechaFin != null && subscriptionFechaFin!.isBefore(DateTime.now()));
  bool get isCancelled => subscriptionEstado == 'cancelada';

  bool get isExpiringSoon {
    if (subscriptionEstado != 'activa' || subscriptionFechaFin == null) return false;
    final daysLeft = subscriptionFechaFin!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 7;
  }

  String get subscriptionStatusLabel {
    if (isPending) return 'Pendiente';
    if (isActive && isExpiringSoon) return 'Por vencer';
    if (isActive) return 'Activa';
    if (isExpired) return 'Vencida';
    if (isCancelled) return 'Cancelada';
    return 'Sin plan';
  }

  factory AdminUserModel.fromMap(Map<String, dynamic> map) {
    final sub = map['subscriptions'] as Map<String, dynamic>?;
    final fechaFinStr = sub?['fecha_fin'] as String?;
    return AdminUserModel(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      email: map['email'],
      telefono: map['telefono'],
      fotoUrl: map['foto_url'],
      rol: map['rol'] ?? 'user',
      derivConnectionStatus: map['deriv_connection_status'] ?? 'disconnected',
      createdAt: (map['fecha_registro'] ?? map['created_at']) != null
          ? DateTime.parse((map['fecha_registro'] ?? map['created_at']))
          : null,
      plan: sub?['plan'],
      subscriptionEstado: sub?['estado'],
      subscriptionFechaFin: fechaFinStr != null ? DateTime.tryParse(fechaFinStr) : null,
    );
  }
}
