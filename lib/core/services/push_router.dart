import 'dart:convert';
import 'package:chat/core/services/chat_route_tracker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'local_notification_service.dart';

class PushRouter {
  final GlobalKey<NavigatorState> navKey;

  Map<String, dynamic>? _pendingData;
  bool _didNavigate = false;

  PushRouter(this.navKey);

  Future<void> init() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    int toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

    // ✅ Foreground messages (Listener الوحيد)
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final eventId = toInt(msg.data['eventId']);
      final senderId = toInt(msg.data['senderId']);
      final receiverId = toInt(msg.data['receiverId']);

      debugPrint(
        'FCM onMessage data: event=$eventId sender=$senderId receiver=$receiverId '
        'openEvent=${ChatRouteTracker.openEventId} openMe=${ChatRouteTracker.openMyUserId} openOther=${ChatRouteTracker.openOtherUserId}',
      );

      // ✅ لو نفس الشات المفتوح -> متطلعش Notification
      if (ChatRouteTracker.shouldSuppressNotification(
        eventId: eventId,
        senderId: senderId,
        receiverId: receiverId,
      )) {
        debugPrint('🚫 [FCM] Suppressing notification - chat is open');
        return;
      }

      // ✅ Optional: لو payload ناقص (data فاضية) متطلعش local notification
      // (تقدر تشيلها لو مش محتاج)
      if (eventId == 0 || senderId == 0 || receiverId == 0) {
        debugPrint('⚠️ [FCM] Missing data keys, skipping local notification: ${msg.data}');
        return;
      }

      await LocalNotificationService.showMessage(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: msg.notification?.title ?? 'New message',
        body: msg.notification?.body ?? '',
        payload: jsonEncode(msg.data),
      );
    });

    // ✅ Background tap (app في الخلفية)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      debugPrint('📱 onMessageOpenedApp data: ${msg.data}');
      _scheduleOpenFromData(msg.data);
    });

    // ✅ Terminated tap (app مقفول)
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      debugPrint('🚀 getInitialMessage: ${initial.data}');
      _scheduleOpenFromData(initial.data);
    }

    // ✅ Local notification tap (من LocalNotificationService)
    LocalNotificationService.onTap = (payload) {
      if (payload == null || payload.isEmpty) return;
      debugPrint('🔔 Local notification tapped: $payload');

      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;

      final map = decoded.cast<String, dynamic>();
      _scheduleOpenFromData(map);
    };
  }

  void _scheduleOpenFromData(Map<String, dynamic> data) {
    _pendingData = data;
    _didNavigate = false;
    _attemptNavigateWithRetry();
  }

  void _attemptNavigateWithRetry() {
    _tryNavigate();
    Future.delayed(const Duration(milliseconds: 200), _tryNavigate);
    Future.delayed(const Duration(milliseconds: 700), _tryNavigate);
    Future.delayed(const Duration(milliseconds: 1500), _tryNavigate);
  }

  void _tryNavigate() {
    if (_didNavigate) return;
    final data = _pendingData;
    if (data == null) return;

    int toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    

    final eventId = toInt(data['eventId']);
    final senderId = toInt(data['senderId']);
    final receiverId = toInt(data['receiverId']);

    if (eventId == 0 || senderId == 0 || receiverId == 0) {
      debugPrint('⚠️ Invalid navigation data: $data');
      return;
    }

    final nav = navKey.currentState;
    if (nav == null) {
      debugPrint('⚠️ Navigator not ready yet...');
      return;
    }

    _didNavigate = true;

    debugPrint('✅ Navigating to /chat: event=$eventId me=$receiverId other=$senderId');

    nav.pushNamedAndRemoveUntil(
      '/chat',
      (route) => false,
      arguments: {
        'eventId': eventId,
        'myUserId': receiverId,  // الرسالة جتلي -> أنا receiver
        'otherUserId': senderId, // اللي بعت -> sender
      },
    );
  }
}
