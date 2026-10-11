// lib/core/constants/app_constants.dart

class AppConstants {
  // App Info
  static const String appName = 'DukaLoop';
  static const String appTagline = 'Offline Shop Manager';
  static const String currency = 'KSh';
  static const String currencySymbol = 'KSh ';

  // Database
  static const String dbName = 'dukaloop.db';
  static const int dbVersion = 1;

  // Invoice
  static const String invoicePrefix = 'INV';

  // Stock
  static const double defaultLowStockThreshold = 5.0;

  // Date Formats
  static const String dateFormat = 'dd MMM yyyy';
  static const String dateTimeFormat = 'dd MMM yyyy, HH:mm';
  static const String timeFormat = 'HH:mm';

  // Pagination / Limits
  static const int searchLimit = 30;
  static const int recentSalesLimit = 20;

  // Validation
  static const int minShopNameLength = 2;
  static const int maxShopNameLength = 60;
  static const int minProductNameLength = 2;
  static const int maxProductNameLength = 100;
}