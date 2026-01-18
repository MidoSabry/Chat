import UIKit
import Flutter
import UserNotifications
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let channelName = "app/active_chat"
  private let kEventId = "active_eventId"
  private let kMyUserId = "active_myUserId"
  private let kOtherUserId = "active_otherUserId"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ✅ Register Flutter plugins (حل MissingPlugin)
    GeneratedPluginRegistrant.register(with: self)

    // ✅ Show notifications while app is in foreground
    UNUserNotificationCenter.current().delegate = self

    // ✅ MethodChannel: Flutter -> iOS (active chat)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }

        let defaults = UserDefaults.standard

        switch call.method {
        case "setActiveChat":
          if let args = call.arguments as? [String: Any] {
            defaults.set(args["eventId"], forKey: self.kEventId)
            defaults.set(args["myUserId"], forKey: self.kMyUserId)
            defaults.set(args["otherUserId"], forKey: self.kOtherUserId)
          }
          result(true)

        case "clearActiveChat":
          defaults.removeObject(forKey: self.kEventId)
          defaults.removeObject(forKey: self.kMyUserId)
          defaults.removeObject(forKey: self.kOtherUserId)
          result(true)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ✅ Helper: safe int conversion
  private func toInt(_ v: Any?) -> Int {
    if let n = v as? NSNumber { return n.intValue }
    if let s = v as? String { return Int(s) ?? 0 }
    return 0
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo

    // بيانات الإشعار (لازم تكون موجودة في data payload)
    let eventId = toInt(userInfo["eventId"])
    let senderId = toInt(userInfo["senderId"])
    let receiverId = toInt(userInfo["receiverId"])

    // الشات المفتوح حالياً (جاي من Flutter)
    let defaults = UserDefaults.standard
    let activeEventId = defaults.integer(forKey: kEventId)
    let activeMyUserId = defaults.integer(forKey: kMyUserId)
    let activeOtherUserId = defaults.integer(forKey: kOtherUserId)

    // هل الإشعار ده لنفس الشات المفتوح؟
    let isSameChat =
      activeEventId != 0 &&
      activeMyUserId != 0 &&
      activeOtherUserId != 0 &&
      eventId == activeEventId &&
      (
        (senderId == activeOtherUserId && receiverId == activeMyUserId) ||
        (senderId == activeMyUserId && receiverId == activeOtherUserId)
      )

    if isSameChat {
      // ✅ نفس الشات → امنع banner
      completionHandler([])
      return
    }

    // ✅ شات تاني → اعرض banner
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}
