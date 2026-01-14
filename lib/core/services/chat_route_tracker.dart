class ChatRouteTracker {
  static int? openEventId;
  static int? openMyUserId;
  static int? openOtherUserId;

  static void setOpenChat({
    required int eventId,
    required int myUserId,
    required int otherUserId,
  }) {
    openEventId = eventId;
    openMyUserId = myUserId;
    openOtherUserId = otherUserId;
  }

  static void clear() {
    openEventId = null;
    openMyUserId = null;
    openOtherUserId = null;
  }

  // ✅ match مضبوط حسب اتجاه الرسالة
  static bool shouldSuppressNotification({
    required int eventId,
    required int senderId,
    required int receiverId,
  }) {
    if (openEventId != eventId) return false;
    if (openMyUserId == null || openOtherUserId == null) return false;

    final me = openMyUserId!;
    final other = openOtherUserId!;

    // الرسالة دي داخل نفس الشات المفتوح؟
    return (senderId == other && receiverId == me) ||
           (senderId == me && receiverId == other);
  }
}
