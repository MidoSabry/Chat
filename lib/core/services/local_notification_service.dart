import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// لازم تكون top-level function (برا أي class) + entry-point
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse details) {
  // هنا تقدر تحفظ data في storage وتفتح الشاشة المناسبة بعدين
  // print فقط للتجربة:
  // ignore: avoid_print
  print('BG notification tapped: ${details.payload}');
}

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  
  static void Function(String? payload)? onTap;

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(android: android, iOS: ios);

     await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        onTap?.call(r.payload);
      },
    );

    // Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // iOS permissions
   await _plugin
    .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
    ?.requestPermissions(alert: true, badge: true, sound: true);

  }

  static Future<void> showMessage({
    required int id,
    required String title,
    required String body,
    String? payload, // اختياري: عشان تعرف تفتح شات معين عند الضغط
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Incoming chat messages',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
