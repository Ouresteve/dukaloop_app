// lib/core/utils/formatters.dart

import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    
    symbol: AppConstants.currency,
    decimalDigits: 0,
  );

  static final NumberFormat _numberFormat = NumberFormat('#,###');

  static String currency(num amount) {
    return _currencyFormat.format(amount);
  }

  static String number(num value) {
    return _numberFormat.format(value);
  }

  static String date(DateTime date) {
    return DateFormat(AppConstants.dateFormat).format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat(AppConstants.dateTimeFormat).format(date);
  }

  static String compactDate(DateTime date) {
    return DateFormat('dd MMM').format(date);
  }
}