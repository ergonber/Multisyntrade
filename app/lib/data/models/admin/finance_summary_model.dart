class FinanceSummaryModel {
  final double totalRevenue;
  final double netRevenue;
  final double commissions;
  final int activeSubscriptions;
  final int pendingPayments;
  final List<Map<String, dynamic>> recentPayments;

  const FinanceSummaryModel({
    this.totalRevenue = 0,
    this.netRevenue = 0,
    this.commissions = 0,
    this.activeSubscriptions = 0,
    this.pendingPayments = 0,
    this.recentPayments = const [],
  });

  factory FinanceSummaryModel.fromMap(Map<String, dynamic> map) {
    return FinanceSummaryModel(
      totalRevenue: (map['total_revenue'] ?? 0).toDouble(),
      netRevenue: (map['net_revenue'] ?? 0).toDouble(),
      commissions: (map['commissions'] ?? 0).toDouble(),
      activeSubscriptions: map['active_subscriptions'] ?? 0,
      pendingPayments: map['pending_payments'] ?? 0,
      recentPayments: (map['recent_payments'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }
}
