import UIKit
import UserNotifications

// React Native is started from SceneDelegate.swift: apps built with the iOS 27 SDK must use the UIScene life cycle
// (Apple TN3187), so the window belongs to the scene, not to the app delegate.
@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // Set before launch finishes (Apple's rule for UNUserNotificationCenter.delegate), so a tap that launched the app is
    // delivered too. Without a delegate iOS shows no banner while the app is in the foreground.
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  // MARK: - UNUserNotificationCenterDelegate

  /// App in the foreground: the ReveChat SDK posts local notifications for agent messages and "chat started" while the
  /// visitor is outside the chat screen. Show them as banners.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if Self.isReveChatNotification(notification) {
      completionHandler([.banner, .list, .sound])
    } else {
      completionHandler([])
    }
  }

  /// Tap on a notification, local or remote, whether the app was in the foreground, in the background or not running.
  /// Handed to react-native-revechat, which sends it to JS as the `notificationTap` event (App.tsx opens the chat).
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    NSLog("[ReveChatExample] notification tapped id=%@", response.notification.request.identifier)
    NotificationCenter.default.post(name: Notification.Name("ReveChatNotificationTapped"), object: response)
    completionHandler()
  }

  /// Local notifications from the SDK are told apart by their identifier. A remote (APNs) push has no ReveChat
  /// identifier; this example has no other pushes, so every remote one counts as ReveChat's.
  private static func isReveChatNotification(_ notification: UNNotification) -> Bool {
    let id = notification.request.identifier
    return id.hasPrefix("ReveChatLanding_")
      || id.hasPrefix("ReveChatAgent_")
      || id.hasPrefix("ReveChatIncomingCall_")
      || id == "OutsideNotification"
      || notification.request.trigger is UNPushNotificationTrigger
  }
}
