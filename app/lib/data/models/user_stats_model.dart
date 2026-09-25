class UserStatsModel {
  final int totalTrades;
  final int wins;
  final int losses;
  final double totalPnl;
  final String? plan;
  final double? capital;
  final double? riskPercentage;

  const UserStatsModel({
    this.totalTrades = 0,
    this.wins = 0,
    this.losses = 0,
    this.totalPnl = 0,
    this.plan,
    this.capital,
    this.riskPercentage,
  });

  double get winRate => totalTrades > 0 ? (wins / totalTrades) * 100 : 0;
  double get lossRate => totalTrades > 0 ? (losses / totalTrades) * 100 : 0;

  factory UserStatsModel.fromMap(Map<String, dynamic> map) {
    return UserStatsModel(
      totalTrades: map['total_trades'] ?? 0,
      wins: map['wins'] ?? 0,
      losses: map['losses'] ?? 0,
      totalPnl: (map['total_pnl'] ?? 0).toDouble(),
      plan: map['plan'],
      capital: map['capital']?.toDouble(),
      riskPercentage: map['risk_percentage']?.toDouble(),
    );
  }
}

class PerformanceModel {
  final int trades;
  final int wins;
  final int losses;
  final double pnl;
  final String period;

  const PerformanceModel({
    this.trades = 0,
    this.wins = 0,
    this.losses = 0,
    this.pnl = 0,
    this.period = 'all',
  });

  double get winRate => trades > 0 ? (wins / trades) * 100 : 0;

  factory PerformanceModel.fromMap(Map<String, dynamic> map) {
    return PerformanceModel(
      trades: (map['trades'] ?? map['total_trades'] ?? 0) as int,
      wins: (map['wins'] ?? 0) as int,
      losses: (map['losses'] ?? 0) as int,
      pnl: (map['pnl'] ?? map['total_pnl'] ?? 0).toDouble(),
      period: map['period'] ?? 'all',
    );
  }
}
