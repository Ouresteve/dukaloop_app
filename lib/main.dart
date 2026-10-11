import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';
import 'app.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //Firebase only on mobile
  if(!kIsWeb && (Platform.isAndroid || Platform.isIOS)){
    try{
      await Firebase.initializeApp();
      await AnalyticsService.instance.init();
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }
  }
  await NotificationService.instance.init();
  runApp(
    const ProviderScope(
      child: DukaLoopApp(),
    ),
  );
}