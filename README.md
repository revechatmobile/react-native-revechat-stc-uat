# react-native-revechat

ReveChat live chat for React Native. A thin wrapper over the native ReveChat Android and iOS SDKs:
tapping a button opens the SDK's own native chat screen. The wrapper contains no chat UI or logic.

Autolinking registers the native module. You do not edit `MainApplication`, `AppDelegate`,
or add any native files.

> **Integrating into an existing app?** Follow the step by step guide: [docs/INTEGRATION.md](docs/INTEGRATION.md).

## Install

```sh
npm install git+ssh://git@github.com/revechatmobile/react-native-revechat-stc-uat.git#v0.1.1
```

Rebuild the app afterwards. A JavaScript reload is not enough, because native code was added.

## Usage

```tsx
import { startChat } from 'react-native-revechat';

await startChat({
  accountId: 'YOUR_ACCOUNT_ID', // required, for example '1234567'
  name: 'Jane Doe',
  email: 'jane@example.com',
  phone: '+15551234567',
  language: 'ar', // optional, see "Language and right-to-left"
});
```

`name`, `email`, `phone` and `language` are optional. `startChat` rejects if `accountId` is empty or the native module
is missing.

### Language and right-to-left

`language` is a language code (`'ar'`, `'en'`, ...). Omit it to follow the device language. Right-to-left languages
(`ar`, `he`, `fa`, `ur`) also switch the SDK screens to a right-to-left layout. It only affects the SDK screens, not your app.
Set it before opening the chat; calling `startChat` again with another value applies to screens opened afterwards.

This is the supported way to show the chat in Arabic. On iOS, frameworks follow the host app's resolved language, so the
SDK would stay English under an Arabic device unless your app also declares `ar` in `CFBundleLocalizations`; with
`language` set you do not need that. Needs an SDK version that has the option (Android SDK 3.4.5 or later, iOS SDK 3.1 or
later); older SDKs ignore it.

### Chat background (light / dark)
The host app chooses the background of the chat screens. Only the neutral background and the dark text on it change;
the theme colour from the widget settings still drives bubbles, toolbar and buttons.

```ts
startChat({
  accountId: '...',
  backgroundTheme: 'dark',      // 'light' (default), 'dark' or 'system' (follows the phone)
  backgroundColor: '#101820',   // optional exact colour, wins over backgroundTheme; the other neutrals are derived from it
});
```

- Leave both out and the chat looks exactly as before: it does not follow the app's or the phone's dark mode.
- It needs an SDK version with background support (Android and iOS); an older SDK ignores the options.
- Changing it while a chat is open updates the open screens.

### Custom font
Use your brand font in every chat screen. The font files are added to the Android and iOS projects of your app (once per
platform), then `startChat` gets their names. The same `.ttf` or `.otf` file and the same names work on both platforms.

```ts
await startChat({
  accountId: ACCOUNT_ID,
  font: {
    regular: 'fonts/Cairo-Regular.ttf',
    medium: 'fonts/Cairo-Medium.ttf', // optional, falls back to regular
    bold: 'fonts/Cairo-Bold.ttf',     // optional, falls back to regular
  },
});
```

Only `regular` is required. Use the **file name** (for example `Cairo-Regular.ttf`), not the font's family or PostScript
name. A name with the folder (`fonts/Cairo-Regular.ttf`), with just the file name (`Cairo-Regular.ttf`) or without the
extension (`Cairo-Regular`) is accepted on both platforms.

**Android**
1. Create the folder `android/app/src/main/assets/fonts/` if it does not exist.
2. Copy the font files into it, for example `android/app/src/main/assets/fonts/Cairo-Regular.ttf`.
3. Rebuild the app (`npx react-native run-android`). Nothing else is needed: no `build.gradle` or manifest change.

**iOS**
1. Open `ios/<YourApp>.xcworkspace` in Xcode.
2. In the Project navigator, right-click your app's folder and choose **Add Files to "<YourApp>"…**
3. Select the font files. Tick **Copy items if needed**, tick your **app target** under *Add to targets*, then **Add**.
   Adding them inside a folder named `fonts` (choose *Create folder references*) is also fine; both places are searched.
4. Check the target: **target → Build Phases → Copy Bundle Resources** must list every font file. If one is missing,
   add it with the **+** button. A font that is not in this list is not found at run time.
5. Rebuild the app (`npx react-native run-ios`). You do **not** need to list the fonts under `UIAppFonts` in
   `Info.plist`; the SDK registers them itself.

**Check it works:** open the chat. The toolbar, messages, forms and the message box use your font. If they still use the
system font, see *If something goes wrong* in `docs/INTEGRATION.md`.

- Leave `font` out to use the system font. Use `.ttf` or `.otf` files.
- Pass the same value on every `startChat` call. A call without `font` goes back to the system font for screens opened afterwards.
- Text the font has no letters for (for example Arabic in a Latin-only font) is shown in the system font.
- Check the font's licence allows embedding in an app.
- Needs the Android SDK 3.4.6 or later; on iOS, `3.1.0-stc-uat` has it. Older SDKs ignore the option.

### Log out

Call `logout()` when your app's user logs out, so the next person on the phone starts a new chat and cannot see the
previous person's messages:

```ts
import { logout, startChat } from 'react-native-revechat';

await logout();                 // closes the chat, clears the local history and the visitor id
// ... the next user logs in to your app, then:
await startChat({ accountId, name, email, phone });   // starts as a new visitor
```

It deletes the chat history, the visitor, tab and session IDs and the saved visitor details, and keeps the account ID,
the push token and the chat sound setting. It also deletes the files the SDK left in the app's private storage. It
rejects with `E_UNSUPPORTED` if the native SDK is too old to have a logout. Details:
[docs/logout-and-bot-callbacks.md](docs/logout-and-bot-callbacks.md).

### Chat screen events and unread count

For a badge on your own chat button, and to know when the chat is on screen:

```ts
import { addChatListener, getUnreadCount } from 'react-native-revechat';

const stopOpen = addChatListener('chatOpened', () => {});
const stopClose = addChatListener('chatClosed', () => {});
const stopCount = addChatListener('unreadCount', ({ count }) => setBadge(count));
const unread = await getUnreadCount(); // messages received while the chat was not open
```

### Chat events (bot callbacks)

Three events tell your app about the bot conversation, for example to log the customer in to the bot:

```ts
import { addChatListener } from 'react-native-revechat';

const stopStart = addChatListener('botStart', ({ botId, sessionId }) => {
  // a bot conversation started or is running (can repeat with the same IDs)
});
const stopHook = addChatListener('webHook', ({ script }) => {
  // the server asked the app to run a script, like  functionName({"chatbot_id":"...","session_id":"..."});
  // read chatbot_id and session_id and call your own login webhook with the customer's token
});
const stopEnd = addChatListener('botFinished', () => {
  // the chat ended
});

// when you no longer need them
stopStart(); stopHook(); stopEnd();
```

- On Android the wrapper attaches its SDK listener as soon as JavaScript uses the module, so events arrive from the
  first moment the chat runs, even before `startChat`. With an Android SDK that allows several listeners (the one
  with `REVEChatEventManager.addListener`), your app's own native `REVEChatEventListener` and this wrapper both receive
  every event. With an older SDK, which keeps one listener, the last one registered receives them.
- Use `widgetId` in `startChat` to pick the widget (bot) the app opens.
- The customer's login token never goes through the SDK: your app calls your own login webhook with the IDs from the
  `webHook` script. The full flow is in [docs/logout-and-bot-callbacks.md](docs/logout-and-bot-callbacks.md).

### API

| Function | Platform | Description |
|---|---|---|
| `startChat({ accountId, name?, email?, phone?, language?, font? })` | Android, iOS | Opens the chat screen. |
| `setDeviceToken(token)` | Android, iOS | Passes the push token: FCM on Android, APNs (hex string) on iOS. Call again when it refreshes. |
| `handlePushMessage(data)` | Android | Hands an FCM data message to the SDK, which shows the chat notification. No-op on iOS. |
| `setLogEnabled(enabled)` | Android | No-op on iOS. |
| `setEnvironment('production' \| 'uat')` | Android, iOS (STC SDK) | Chooses the STC chat server; production is the default. Call before `startChat`. Rejects with `E_UNSUPPORTED` on other SDK builds. |
| `addChatListener(event, listener)` | Android, iOS | Listens to `'botStart'`, `'webHook'`, `'botFinished'`, `'chatOpened'`, `'chatClosed'` or `'unreadCount'`, and on iOS `'notificationTap'` (see [Opening the chat from a tap](#opening-the-chat-from-a-tap)). Returns a function that removes the listener. |
| `getUnreadCount()` | Android, iOS | Messages that arrived while the chat screen was closed (for a badge). Details in [docs/logout-and-bot-callbacks.md](docs/logout-and-bot-callbacks.md). |
| `logout()` | Android, iOS | Closes the chat and clears the local chat history, visitor id and saved visitor details, so the next `startChat` creates a new visitor. Call it when your app's user logs out. |
| `clearAccountData(accountId)` | Android, iOS | Deletes the chat history and visitor identity stored for one account. `startChat` with another `accountId` switches to that account's own data automatically. Android SDK 3.4.6 or later, iOS `3.1.0-stc-uat`. |
| `setServiceNotification({ title, content })` | Android | Text of the notification shown while the chat service runs. No-op on iOS. |

Calls that do not apply to the current platform resolve without error, so no `Platform.OS` checks are needed.
See [Push notifications](#push-notifications) for how to wire the last two.

## Android setup

The wrapper adds the ReveChat Maven repositories and the SDK dependency for you. Your app still needs:

| Requirement | Why |
|---|---|
| `minSdkVersion` 24 or higher, `compileSdkVersion` 35 or higher | SDK requirement |
| A current JDK for Gradle (17.0.14+ or 21) | Older JDKs may not trust the ReveChat Maven certificate (`PKIX path building failed`). JDK 17.0.14 and 17.0.16 were tested and connect fine; JDK 21 was used for the builds. |
| `android/app/build.gradle`: `android { buildFeatures { dataBinding true } }` | The SDK's chat screens use Data Binding |
| `android/gradle.properties`: `android.enableJetifier=true` | **Only for SDK 3.4.0.** It pulls in old support libraries through `com.vanniktech:emoji:0.6.0` (`Duplicate class android.support.v4...`). SDK 3.4.5 does not, and builds without it. |

The SDK's manifest sets `android:usesCleartextTraffic="true"` (it fetches link previews for `http://` links). If your
own `AndroidManifest.xml` also sets that attribute, the manifest merge fails (the React Native template does: release builds
fail with `Manifest merger failed ... usesCleartextTraffic`). Tell the merger to keep your value:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <application
        android:usesCleartextTraffic="${usesCleartextTraffic}"
        tools:replace="android:usesCleartextTraffic"
        ... >
```

`tools:replace` needs your manifest to set the attribute too. If it does not, there is no conflict and nothing to add.

### Text chat only: removing call and screen-sharing permissions

A chat-only build of the SDK is not available. If you only need text chat with attachments, you can remove the call and
screen-sharing permissions and services from your app, **provided voice calls, video calls and screen sharing are
switched off for your account**. Otherwise the call buttons still show in the chat although their services are removed.

Add to `android/app/src/main/AndroidManifest.xml` (the `<manifest>` tag needs
`xmlns:tools="http://schemas.android.com/tools"`). Put the `<service>` lines inside your existing `<application>` tag.

```xml
<!-- Calls and screen sharing: permissions -->
<uses-permission android:name="android.permission.READ_PHONE_STATE" tools:node="remove" />
<uses-permission android:name="android.permission.MANAGE_OWN_CALLS" tools:node="remove" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" tools:node="remove" />
<uses-permission android:name="android.permission.BLUETOOTH" tools:node="remove" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" tools:node="remove" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_PHONE_CALL" tools:node="remove" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" tools:node="remove" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CAMERA" tools:node="remove" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" tools:node="remove" />

<application>
    <!-- Calls and screen sharing: services -->
    <service android:name="com.revesoft.revechatsdk.service.MediaProjectionService" tools:node="remove" />
    <service android:name="com.revesoft.revechatsdk.service.VoiceVideoCallService" tools:node="remove" />
    <service android:name="com.revesoft.revechatsdk.service.CallForeGroundService" tools:node="remove" />
    <service android:name="com.revesoft.revechatsdk.service.CallNotificationService" tools:node="remove" />
</application>
```

Keep the rest. In particular, text chat needs `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_REMOTE_MESSAGING` (declare
`remoteMessaging` in Google Play), `CAMERA` is used for photos, and `RECORD_AUDIO` for voice messages.

### Maven repository

Everything the SDK needs that is not on Maven Central or Google is on one ReveChat repository,
`https://jfrog-artifact.revechat.com/artifactory/artifactory/` (the SDK itself, `com.revesoft.ccp:ccp`,
`com.revesoft.webrtc:libwebrtc`, `com.github.squti:Android-Wave-Recorder` and
`com.github.bastienpaulfr:Treessence`). You do not need JitPack or the iptelephony repository any more. Declare it in
your app's repositories:

```groovy
// android/build.gradle
allprojects {
  repositories {
    maven {
      url "https://jfrog-artifact.revechat.com/artifactory/artifactory/"
      content {
        includeGroupByRegex "com\\.revesoft.*"
        includeGroup "com.github.squti"
        includeGroup "com.github.bastienpaulfr"
      }
    }
  }
}
```

Declare it yourself, as above, if your project uses `org.gradle.configureondemand=true`: the repositories the wrapper
adds from its own build file can be applied after `:app` has already tried to resolve the SDK, and then `:app` fails to
find `revechatsdk`.

To use another SDK version, set it in `android/gradle.properties`:

```properties
ReveChat_sdkVersion=3.4.8_stc
```

## iOS setup

The wrapper's podspec depends on the `ReveChatSDK` pod, so `pod install` brings in the SDK. Do not add a
`pod 'ReveChatSDK'` line yourself.

The default is **`3.1.0-stc-uat`**, the STC build of ReveChatSDK 3.1.0. It connects to STC production
(`chatbot.stc.com.kw`) by default and to UAT (`chatbot-uat.stc.com.kw`) after `setEnvironment('uat')`. It is an
XCFramework with device and simulator (arm64, x86_64) slices whose only dependency is `WebRTC-lib`, so **the Podfile
needs no edits for ReveChat**: no hooks, no `ENV` flags. It works with `use_frameworks! :linkage => :static` or
`:dynamic` and with React Native's prebuilt dependencies. Minimum iOS 15.0.

```sh
cd ios && pod install
```

**Installed `3.1.0-stc-uat` before 26 Nov 2026?** The SDK behind that version was updated on 26 Nov 2026 under the same
version number (production / UAT switch, logout, bot events, notification fixes), and CocoaPods keeps using its cached
download. Clear it once, install again, then *Clean Build Folder* in Xcode and rebuild:

```sh
pod cache clean ReveChatSDK --all
rm -rf ios/Pods/ReveChatSDK
cd ios && pod install
```

To use another SDK version, set it before `pod install`: `REVECHAT_IOS_SDK_VERSION='3.1.0' pod install`. A pre-release
such as `3.1.0-stc-uat` must be named exactly; `~> 3.1` will not resolve it.

Add these usage descriptions to `Info.plist` (the SDK uses the camera, microphone and photo library; wording is yours):

```xml
<key>NSCameraUsageDescription</key>
<string>Take photos and videos to send in the chat, and for video calls.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Record voice messages and make voice and video calls.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Choose photos and videos to send in the chat.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Save photos and videos from the chat to your library.</string>
```

For calls and push, also enable the Push Notifications and Background Modes (Voice over IP, Audio) capabilities, as in the
ReveChat iOS guide.

Building with Xcode 27 (iOS 27 SDK) adds two app-wide requirements that are not caused by ReveChat:

- **Deployment targets of 15.0 or later.** Xcode 27 rejects lower ones, and `react_native_post_install` does not raise
  resource-bundle targets (`RNCAsyncStorage_resources` declares 13.4). The `post_install` loop in Step 3.1 of
  [docs/INTEGRATION.md](docs/INTEGRATION.md) fixes it, as in `example/ios/Podfile`.
- **The UIScene life cycle.** Without it iOS does not launch the app on a device (`UIScene life cycle is required for
  apps built with this SDK`, Apple TN3187). See Step 3.3 of the integration guide and the example's
  `SceneDelegate.swift`.

## Push notifications

Use your usual Firebase setup; the wrapper only forwards to the SDK. With `@react-native-firebase/messaging`:

```ts
import messaging from '@react-native-firebase/messaging';
import { Platform } from 'react-native';
import { setDeviceToken, handlePushMessage } from 'react-native-revechat';

// Token: send it on start and whenever it refreshes.
const token = Platform.OS === 'ios' ? await messaging().getAPNSToken() : await messaging().getToken();
if (token) await setDeviceToken(token);
messaging().onTokenRefresh((t) => setDeviceToken(t));

// Android: let the SDK show ReveChat notifications.
messaging().onMessage((m) => handlePushMessage(m.data ?? {}));
messaging().setBackgroundMessageHandler(async (m) => handlePushMessage(m.data ?? {}));
```

- **Android 13+:** the app must request the `POST_NOTIFICATIONS` runtime permission
  (`PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS)`), or the SDK's notifications will not show.
- **iOS:** `setDeviceToken` sets the SDK's `APNSToken`, which is sent to the server. The SDK registers for VoIP (PushKit)
  itself. Showing ReveChat notifications while the app is open needs a notification delegate in your app, see
  [iOS: showing ReveChat notifications while the app is open](#ios-showing-revechat-notifications-while-the-app-is-open).

### iOS: showing ReveChat notifications while the app is open

While the chat is open in the background, or the visitor has closed the chat screen and is elsewhere in your app, the
iOS SDK posts **local notifications** for agent messages, "chat started" and incoming calls. iOS shows a notification
while your app is in the foreground only if your app's `UNUserNotificationCenter` delegate asks for it, so without a
delegate these go straight to Notification Center with no banner.

The SDK does not set the delegate itself: an app has only one, and taking it would break your other notifications. Set
it in your `AppDelegate` before launch finishes (Apple's rule, so a tap that launched the app is delivered too):

```swift
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  // App in the foreground: show ReveChat's notifications as banners.
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let id = notification.request.identifier
    let isReveChat = id.hasPrefix("ReveChatLanding_") || id.hasPrefix("ReveChatAgent_")
      || id.hasPrefix("ReveChatIncomingCall_") || id == "OutsideNotification"
    completionHandler(isReveChat ? [.banner, .list, .sound] : [])  // keep your own rule for other notifications
  }

  // Tap on any notification, local or remote, in any app state: hand it to react-native-revechat.
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    NotificationCenter.default.post(name: Notification.Name("ReveChatNotificationTapped"), object: response)
    completionHandler()
  }
}
```

The local notifications carry no `userInfo`; the identifier is the only way to recognise them:

| Identifier | When the SDK posts it |
|---|---|
| `ReveChatAgent_<messageId>` | Agent message while the chat screen is open and the app is in the background |
| `ReveChatLanding_<messageId>` | Agent message after the visitor closed the chat screen |
| `OutsideNotification` | An agent picked up the chat after the visitor closed the chat screen |
| `ReveChatIncomingCall_<uuid>` | Agent call while the app is in the background (alongside the CallKit screen) |

- **Already using a notification library** (`@react-native-firebase/messaging`, notifee,
  `@react-native-community/push-notification-ios`)? It sets the delegate. Add the ReveChat rule to that library's
  foreground handling instead, and check that it passes notifications it does not own (these local ones and ReveChat's
  APNs pushes) on to your code.
- **The app in the background:** the SDK can post these only for the few seconds before iOS suspends the app and the
  chat connection drops. After that only the ReveChat server's push (APNs for messages, VoIP for calls) reaches the
  visitor.
- **Remote pushes:** ReveChat's APNs pushes are not local notifications and have no ReveChat identifier. When the app is
  in the background or not running iOS shows them without asking the delegate; a tap on one reaches the same
  `didReceive` method.

#### Opening the chat from a tap

With `didReceive` posting `ReveChatNotificationTapped` as above, the wrapper sends each tap to JS as the
`notificationTap` event. Add the listener once when your app starts:

```ts
import { addChatListener, startChat } from 'react-native-revechat';

useEffect(
  () =>
    addChatListener('notificationTap', (tap) => {
      // 'message', 'chatStarted', 'call': the SDK's own notifications. 'remote': an APNs push, check tap.data.
      if (tap.kind !== 'other') {
        startChat({ accountId: '1234567', name, email, phone });
      }
    }),
  []
);
```

- **A tap is kept until a `notificationTap` listener is there to take it** (the latest one), including the tap that
  launched the app, even if other chat listeners were added first. Add the listener only once your visitor details are
  available.
- **`startChat` while the chat is already open** does nothing, so you can call it for every ReveChat tap.
- **`remote`:** ReveChat's APNs pushes and your own both arrive as `remote`; tell them apart by `tap.data` (the full
  payload).
- **Swiping a notification away** is not a tap and is not reported.
- **Android:** the SDK opens the chat from its own notifications; this event does not fire.
- If another library owns the notification delegate, post `ReveChatNotificationTapped` with the
  `UNNotificationResponse` from wherever it hands you taps.

## Troubleshooting

| What you see | What to do |
|---|---|
| `PKIX path building failed` | Run Gradle on a newer JDK (17.0.14+ or 21). |
| `Duplicate class android.support.v4...` | Add `android.enableJetifier=true`. |
| App crashes when the chat screen opens, `ClassNotFoundException: androidx.databinding.DataBinderMapperImpl` | Add `buildFeatures { dataBinding true }` to `android/app/build.gradle` and rebuild. The wrapper cannot enable this for your app. |
| `Manifest merger failed ... usesCleartextTraffic` | Add `tools:replace="android:usesCleartextTraffic"` to `<application>` (see above). |
| `react-native-revechat: the native module 'ReveChat' was not found` | Rebuild the app (and run `pod install` on iOS). Expo Go is not supported; use a development build. |
| iOS: crash at launch, `Symbol not found: __ZN8facebook6hermes3cdp11CDPDebugAPI...` (in `React.framework`, expected in `hermesvm.framework`) | A Release Hermes is left in `ios/Pods/hermes-engine` from an earlier Release build while you build Debug. Not ReveChat-specific. `rm -rf ios/Pods/hermes-engine && pod install`. |
| iOS `pod install`: `Unable to find a specification for ReveChatSDK (= 3.1.0-stc-uat)` | Run `pod repo update` (the CocoaPods CDN index was older than the release). |
| iOS: the app is aborted at launch or when the SDK touches the microphone | Add the `Info.plist` usage descriptions above. |
| iOS build: `IPHONEOS_DEPLOYMENT_TARGET is set to 13.4, but the range of supported deployment target versions is 15.0 to ...` | Xcode 27. Add the `post_install` loop (see iOS setup). |
| iOS device: the app does not start, `UIScene life cycle is required for apps built with this SDK` | Xcode 27. Adopt the scene life cycle (see iOS setup). |
| iOS: `setEnvironment`, `logout`, the bot events or notifications after closing the chat do nothing, or the chat still connects to UAT only | The `3.1.0-stc-uat` SDK downloaded before 26 Nov 2026 is cached. Clear it as in [iOS setup](#ios-setup), then *Clean Build Folder* and rebuild. |
| iOS: `font`, `backgroundTheme` and `clearAccountData` have no effect | An older download of `ReveChatSDK 3.1.0-stc-uat` is cached. `pod cache clean ReveChatSDK --all && rm -rf ios/Pods/ReveChatSDK && cd ios && pod install`. |
| iOS, local SDK pod (`:path`): `unrecognized selector` for a new SDK method such as `setLanguage:` | Xcode embeds a stale copy. Delete `<DerivedData>/Build/Products/<config>-iphonesimulator/XCFrameworkIntermediates/ReveChatSDK` and the app's `Frameworks/ReveChatSDK.framework`, then rebuild. SDK developers only. |
| `pod install`: "React Native requires Xcode >= 16.1" | React Native 0.86 needs Xcode 16.1 or later (macOS 14.5 or later). |
