import 'dart:io';
import 'package:flutter/services.dart';

class IOSActiveChat {
  static const _ch = MethodChannel('app/active_chat');

  static Future<void> setActiveChat({
    required int eventId,
    required int myUserId,
    required int otherUserId,
  }) async {
    if (!Platform.isIOS) return;
    await _ch.invokeMethod('setActiveChat', {
      'eventId': eventId,
      'myUserId': myUserId,
      'otherUserId': otherUserId,
    });
  }

  static Future<void> clearActiveChat() async {
    if (!Platform.isIOS) return;
    await _ch.invokeMethod('clearActiveChat');
  }
}
