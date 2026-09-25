import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _currencyFormat = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );

  static final _percentFormat = NumberFormat.decimalPattern('es');

  static final _compactFormat = NumberFormat.compactCurrency(
    symbol: '\$',
    decimalDigits: 1,
  );

  static String currency(double amount) => _currencyFormat.format(amount);

  static String percent(double value) => '${value.toStringAsFixed(1)}%';

  static String compact(double value) => _compactFormat.format(value);

  static String rValue(double r) {
    if (r > 0) return '+${r.toStringAsFixed(2)}R';
    return '${r.toStringAsFixed(2)}R';
  }

  static String dateTime(DateTime dt) => DateFormat('dd MMM yyyy, HH:mm').format(dt);

  static String dateOnly(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);

  static String timeOnly(DateTime dt) => DateFormat('HH:mm').format(dt);

  static String relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return dateOnly(dt);
  }

  static String multiplier(int m) => 'x$m';
}
