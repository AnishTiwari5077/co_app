import 'package:intl/intl.dart';

/// Currency and number formatting utilities for NPR (Nepali Rupee).
class CurrencyUtils {
  CurrencyUtils._();

  static final _compact  = NumberFormat.compact(locale: 'en_IN');
  static final _currency = NumberFormat('#,##,##0.00', 'en_IN');
  static final _plain    = NumberFormat('#,##,##0', 'en_IN');

  /// Format amount as NPR with symbol: "NPR 1,23,456.00"
  static String format(double amount) => 'NPR ${_currency.format(amount)}';

  /// Format without NPR prefix: "1,23,456.00"
  static String formatRaw(double amount) => _currency.format(amount);

  /// Format as compact: "NPR 1.2L", "NPR 4.5Cr"
  static String formatCompact(double amount) {
    if (amount >= 10000000) {
      return 'NPR ${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return 'NPR ${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return 'NPR ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }

  /// Format whole number: "1,23,456"
  static String formatInteger(int amount) => _plain.format(amount);

  /// Parse a formatted string back to double.
  static double parse(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Returns a sign-prefixed string for credit/debit display.
  static String formatSigned(double amount, {bool isCredit = true}) {
    final sign = isCredit ? '+' : '-';
    return '$sign NPR ${_currency.format(amount.abs())}';
  }
}
