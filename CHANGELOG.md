## 0.1.1

* Example app and docs use Android SDK `3.4.8_stc` (STC build with the UAT / production switch, from the ReveChat Maven repository). Android SDK 3.4.8 adds several event listeners, main-thread events, file cleanup on logout, no storage permissions, and a clean connection when the server is switched.

* `logout()`: clears the local chat data and the visitor id so the next chat starts as a new visitor.
* `addChatListener('botStart' | 'webHook' | 'botFinished', listener)`: bot conversation callbacks, as the native SDKs' event listeners.
* `widgetId` option for `startChat`.
* `addChatListener('chatOpened' | 'chatClosed' | 'unreadCount', listener)` and `getUnreadCount()`: the chat screen events and the unread message count, on Android and iOS.
* `setEnvironment('production' | 'uat')` for the STC SDK builds.
* iOS: `addChatListener('notificationTap', listener)`: a tap on a notification, passed on by the app's notification
  delegate (post `ReveChatNotificationTapped` with the `UNNotificationResponse`), including the tap that launched the
  app. README and integration guide show the `AppDelegate` code that also shows ReveChat banners while the app is open.
  A tap is kept until a `notificationTap` listener takes it, even when other chat listeners were added first.
* iOS SDK: the `3.1.0-stc-uat` zip was replaced on 26 Nov 2026 under the same version with the STC build that has the
  production / UAT switch (production by default), logout, bot events and the notification fixes. Apps that installed
  it before must run `pod cache clean ReveChatSDK --all`, delete `ios/Pods/ReveChatSDK` and `pod install` again.

## 0.1.0

* First release. `startChat`, `setDeviceToken`, `handlePushMessage`, `setLogEnabled`, `setServiceNotification`.
* Android: tested with React Native 0.88.1 and ReveChat SDK 3.4.5 on a physical device (debug and release builds).
* iOS: depends on the `ReveChatSDK` pod, default `3.1.0-stc-uat` (STC UAT build; XCFramework, simulator supported, no
  Podfile hooks needed). Tested with React Native 0.86.2 on the iOS simulator, static frameworks.
