class SubscriptionModel {
  final String id;
  final String userId;
  final String plan;
  final String? planDisplayName;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String estado;
  final DateTime createdAt;

  const SubscriptionModel({
    required this.id,
    required this.userId,
    required this.plan,
    this.planDisplayName,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estado,
    required this.createdAt,
  });

  bool get isActive => estado == 'activa' && DateTime.now().isAfter(fechaInicio) && DateTime.now().isBefore(fechaFin);
  bool get isExpired => estado == 'vencida' || DateTime.now().isAfter(fechaFin);
  bool get isCancelled => estado == 'cancelada';
  bool get isFree => plan == 'gratis';
  bool get isBasico => plan == 'basico';
  bool get isPro => plan == 'pro';
  bool get isVip => plan == 'vip';

  int get daysRemaining {
    if (!isActive) return 0;
    return fechaFin.difference(DateTime.now()).inDays;
  }

  String get displayName {
    if (planDisplayName != null) return planDisplayName!;
    switch (plan) {
      case 'gratis': return 'Gratuito';
      case 'basico': return 'Plan Básico';
      case 'pro': return 'Plan Pro';
      case 'vip': return 'Plan VIP';
      default: return plan;
    }
  }

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    return SubscriptionModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      plan: map['plan'] ?? 'gratis',
      planDisplayName: map['plan_display_name'],
      fechaInicio: DateTime.parse(map['fecha_inicio'] ?? DateTime.now().toIso8601String()),
      fechaFin: DateTime.parse(map['fecha_fin'] ?? DateTime.now().toIso8601String()),
      estado: map['estado'] ?? 'activa',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'plan': plan,
    'plan_display_name': displayName,
    'fecha_inicio': fechaInicio.toIso8601String(),
    'fecha_fin': fechaFin.toIso8601String(),
    'estado': estado,
  };
}
