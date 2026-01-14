import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // هنا بيشتغل حتى لو التطبيق مقفول (background/terminated)
  // لا تستخدم BuildContext هنا
  // ممكن تعمل logging بسيط لو حابب:
  // print('BG message: ${message.messageId}');
}

class PushService {
  static Future<void> init() async {
    // ✅ Init local notifications plugin (مفيد للتعامل مع التراخيص/القنوات)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _local.initialize(initSettings);

    // ✅ Permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ✅ iOS: امنع system notification في foreground
    // (خلي التحكم كله بإيد PushRouter + LocalNotificationService)
    if (Platform.isIOS) {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
    }

    // ✅ Background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // ❌ مهم: شيلنا FirebaseMessaging.onMessage.listen من هنا
    // علشان مايبقاش عندك اتنين listeners يطلعوا Notifications
  }

  static Future<String?> getToken() async {
    return FirebaseMessaging.instance.getToken();
  }
}
