class AdminStatsModel {
  final int totalUsers;
  final int newUsersWeek;
  final int activeSubscriptions;
  final int signalsToday;
  final int activeSignals;
  final int wonSignals;
  final int lostSignals;
  final double effectiveness;
  final int vipUsers;
  final int freeUsers;
  final double totalRevenue;

  const AdminStatsModel({
    this.totalUsers = 0,
    this.newUsersWeek = 0,
    this.activeSubscriptions = 0,
    this.signalsToday = 0,
    this.activeSignals = 0,
    this.wonSignals = 0,
    this.lostSignals = 0,
    this.effectiveness = 0,
    this.vipUsers = 0,
    this.freeUsers = 0,
    this.totalRevenue = 0,
  });

  factory AdminStatsModel.fromMap(Map<String, dynamic> map) {
    return AdminStatsModel(
      totalUsers: map['total_users'] ?? 0,
      newUsersWeek: map['new_users_week'] ?? 0,
      activeSubscriptions: map['active_subscriptions'] ?? 0,
      signalsToday: map['signals_today'] ?? 0,
      activeSignals: map['active_signals'] ?? 0,
      wonSignals: map['won_signals'] ?? 0,
      lostSignals: map['lost_signals'] ?? 0,
      effectiveness: (map['effectiveness'] ?? 0).toDouble(),
      vipUsers: map['vip_users'] ?? 0,
      freeUsers: map['free_users'] ?? 0,
      totalRevenue: (map['total_revenue'] ?? 0).toDouble(),
    );
  }
}
