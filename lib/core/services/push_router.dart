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
    // Permissions (خصوصًا iOS)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    int toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

    // ✅ Foreground FCM: NO local notifications هنا
    // لأننا هنخلي SignalR هو المسؤول عن إشعارات الـ foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final eventId = toInt(msg.data['eventId']);
      final senderId = toInt(msg.data['senderId']);
      final receiverId = toInt(msg.data['receiverId']);

      debugPrint(
        '📩 [FCM foreground] data: event=$eventId sender=$senderId receiver=$receiverId '
        'openEvent=${ChatRouteTracker.openEventId} openMe=${ChatRouteTracker.openMyUserId} openOther=${ChatRouteTracker.openOtherUserId} '
        'notificationTitle=${msg.notification?.title}',
      );

      // ✅ لا تعمل showMessage هنا (منع duplicates)
      // لو عايز فقط تمنع “system banner” على iOS في foreground،
      // اعمل setForegroundNotificationPresentationOptions في PushService (انت عاملها)
      return;
    });

    // ✅ Background tap (app في الخلفية)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      debugPrint('📱 [FCM onMessageOpenedApp] data: ${msg.data}');
      _scheduleOpenFromData(msg.data);
    });

    // ✅ Terminated tap (app مقفول)
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      debugPrint('🚀 [FCM getInitialMessage] data: ${initial.data}');
      _scheduleOpenFromData(initial.data);
    }

    // ✅ Local notification tap (الإشعارات اللي انت بتطلعها من SignalR)
    LocalNotificationService.onTap = (payload) {
      if (payload == null || payload.isEmpty) return;
      debugPrint('🔔 [LocalNotification tapped] payload: $payload');

      try {
        final decoded = jsonDecode(payload);
        if (decoded is! Map) return;

        final map = decoded.cast<String, dynamic>();
        _scheduleOpenFromData(map);
      } catch (e) {
        debugPrint('⚠️ Failed to decode payload: $e');
      }
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

    // ✅ Important:
    // - لو الـ payload جاي من FCM: receiverId = أنا (اللي استقبل)
    // - senderId = اللي بعت
    debugPrint('✅ Navigating to /chat: event=$eventId me=$receiverId other=$senderId');

    nav.pushNamedAndRemoveUntil(
      '/chat',
      (route) => false,
      arguments: {
        'eventId': eventId,
        'myUserId': receiverId,
        'otherUserId': senderId,
      },
    );
  }
}
