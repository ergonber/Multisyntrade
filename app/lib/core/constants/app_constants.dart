class AppConstants {
  AppConstants._();

  static const String appName = 'SynTrade';
  static const String appVersion = '2.0.0';

  static const int maxPasswordLength = 128;
  static const int minPasswordLength = 6;
  static const int maxLoginAttempts = 5;
  static const int loginBlockDurationMinutes = 15;

  static const double minCapital = 1.0;
  static const double maxCapital = 1000000.0;
  static const double maxAccumulatedRisk = 15.0;
  static const int maxSimultaneousSignals = 5;
  static const int maxOpenSignals = 10;

  static const int sessionTimeoutMinutes = 15;
  static const int refreshTokenDays = 30;

  static const List<double> riskOptions = [1.0];
  static const double defaultRisk = 2.0;

  /// Riesgo por tramo de saldo (debe coincidir con el deriv-bridge).
  /// < 10 no opera | 10-99: 1% | 100-1000: 3% | 1001-10000: 2% | > 10000: 1%
  static double? riskPercentForBalance(double balance) {
    if (balance < 10) return null;
    if (balance < 100) return 1;
    if (balance <= 1000) return 3;
    if (balance <= 10000) return 2;
    return 1;
  }

  static const int defaultEntryWindowMinutes = 5;
  static const int minEntryWindowMinutes = 1;
  static const int maxEntryWindowMinutes = 60;

  static const double rPublishableMin = -3.00;
  static const double rPublishableMax = 20.00;

  static const int founderPlanDurationDays = 45;

  static const int pushLatencyTargetMs = 5000;

  static const int auditLogRetentionMonths = 24;
}
