import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _compactCurrency = NumberFormat('#,##0', 'en_US');
  static final NumberFormat _weightFormat = NumberFormat('#,##0.##', 'en_US');

  static String formatCurrency(double amount) {
    if (amount % 1 == 0) {
      return '₨ ${_compactCurrency.format(amount)}';
    }
    return '₨ ${_currencyFormat.format(amount)}';
  }

  static String formatWeight(double kg) {
    return '${_weightFormat.format(kg)} kg';
  }

  static String formatQuantity(double qty) {
    if (qty % 1 == 0) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(1);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}

