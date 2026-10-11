import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  FirebaseAnalytics? _analytics;
  bool _ready = false;

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> init() async {
    if (!isSupported) return;
    try {
      _analytics = FirebaseAnalytics.instance;
      _ready = true;
      await logAppOpen();
    } catch (e) {
      debugPrint('Analytics init failed: $e');
      _ready = false;
    }
  }

  Future<void> logAppOpen() async {
    if (!_ready) return;
    await _analytics?.logAppOpen();
  }

  Future<void> logSaleCompleted({
    required double value,
    required int itemCount,
    required bool isCredit,
  }) async {
    if (!_ready) return;
    await _analytics?.logEvent(
      name: 'sale_completed',
      parameters: {
        'value': value,
        'item_count': itemCount,
        'is_credit': isCredit ? 1 : 0,
        'currency': 'KES',
      },
    );
  }

  Future<void> logProductAdded() async {
    if (!_ready) return;
    await _analytics?.logEvent(name: 'product_added');
  }

  Future<void> logDebtPayment({required double amount}) async {
    if (!_ready) return;
    await _analytics?.logEvent(
      name: 'debt_payment',
      parameters: {
        'value': amount,
        'currency': 'KES',
      },
    );
  }

  Future<void> logLossRecorded({required double quantity}) async {
    if (!_ready) return;
    await _analytics?.logEvent(
      name: 'loss_recorded',
      parameters: {
        'quantity': quantity,
      },
    );
  }

  Future<void> logShopCreated() async {
    if (!_ready) return;
    await _analytics?.logEvent(name: 'shop_created');
  }
}