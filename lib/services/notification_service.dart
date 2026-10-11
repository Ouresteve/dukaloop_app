import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../repositories/repositories.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'low_stock';
  static const _channelName = 'Low Stock Alerts';
  static const _notificationId = 1001;

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      _initialized = true; // Windows: no-op for MVP
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);

    // Android 13+ permission
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Call after app open, sale, restock, loss
  Future<void> checkLowStock(String shopId, {double threshold = 5}) async {
    if (!_initialized) await init();
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final items = await AnalyticsRepository().getLowStock(shopId, threshold: threshold);

    if (items.isEmpty) {
      await _plugin.cancel(_notificationId);
      return;
    }

    final count = items.length;
    final preview = items
        .take(3)
        .map((e) => '${e['product_name']} (${e['stock_quantity']})')
        .join(', ');

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Alerts when products are running low',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      _notificationId,
      count == 1 ? '1 item is low on stock' : '$count items are low on stock',
      preview,
      details,
    );
  }
}