import 'package:flutter/material.dart';
import '../../data/repositories/subscriptions_repository.dart';
import '../../data/models/subscription_model.dart';

enum SubscriptionStatus { initial, loading, pending, active, expired, cancelled, unknown }

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionsRepository _repo = SubscriptionsRepository();

  SubscriptionModel? _subscription;
  SubscriptionStatus _status = SubscriptionStatus.initial;
  String? _error;

  SubscriptionModel? get subscription => _subscription;
  SubscriptionStatus get status => _status;
  String? get error => _error;

  bool get hasAccess => _status == SubscriptionStatus.active;
  bool get isPending => _status == SubscriptionStatus.pending;
  bool get isExpired => _status == SubscriptionStatus.expired;
  bool get isCancelled => _status == SubscriptionStatus.cancelled;
  bool get isBlocked => _status == SubscriptionStatus.pending ||
      _status == SubscriptionStatus.expired ||
      _status == SubscriptionStatus.cancelled;

  int get daysRemaining => _subscription?.daysRemaining ?? 0;

  String get statusLabel {
    switch (_status) {
      case SubscriptionStatus.pending:
        return 'Pendiente de activación';
      case SubscriptionStatus.active:
        return 'Activa';
      case SubscriptionStatus.expired:
        return 'Suscripción vencida';
      case SubscriptionStatus.cancelled:
        return 'Suscripción cancelada';
      case SubscriptionStatus.loading:
        return 'Cargando...';
      default:
        return '';
    }
  }

  Future<void> loadSubscription(String userId) async {
    _status = SubscriptionStatus.loading;
    notifyListeners();

    try {
      final sub = await _repo.getMySubscription(userId);
      _subscription = sub;

      if (sub == null) {
        _status = SubscriptionStatus.unknown;
      } else {
        _status = _resolveStatus(sub);
      }
    } catch (e) {
      _error = 'Error al cargar suscripción';
      _status = SubscriptionStatus.unknown;
    }
    notifyListeners();
  }

  SubscriptionStatus _resolveStatus(SubscriptionModel sub) {
    switch (sub.estado) {
      case 'pendiente':
        return SubscriptionStatus.pending;
      case 'activa':
        if (sub.fechaFin.isBefore(DateTime.now())) {
          return SubscriptionStatus.expired;
        }
        return SubscriptionStatus.active;
      case 'vencida':
        return SubscriptionStatus.expired;
      case 'cancelada':
        return SubscriptionStatus.cancelled;
      default:
        return SubscriptionStatus.unknown;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
