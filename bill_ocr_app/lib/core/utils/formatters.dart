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

  static String formatCompactCurrency(double amount) {
    if (amount >= 100000) {
      final lacs = amount / 100000.0;
      return '₨ ${lacs.toStringAsFixed(1)} Lac';
    }
    if (amount >= 1000) {
      final k = amount / 1000.0;
      return '₨ ${k.toStringAsFixed(1)}k';
    }
    return '₨ ${_compactCurrency.format(amount)}';
  }

  static String formatWeight(double kg) {
    return '${_weightFormat.format(kg)} kg';
  }

  /// Formats weight in Pakistani Mandi maunds (1 Maund = 40 kg)
  static String formatMaunds(double kg) {
    final maunds = kg / 40.0;
    if (maunds % 1 == 0) {
      return '${maunds.toInt()} من';
    }
    return '${maunds.toStringAsFixed(1)} من';
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

typedef AppFormatters = Formatters;
