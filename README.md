# react-native-revechat

ReveChat live chat for React Native. A thin wrapper over the native ReveChat Android and iOS SDKs:
tapping a button opens the SDK's own native chat screen. The wrapper contains no chat UI or logic.

Autolinking registers the native module. You do not edit `MainApplication`, `AppDelegate`,
or add any native files.

> **Integrating into an existing app?** Follow the step by step guide: [docs/INTEGRATION.md](docs/INTEGRATION.md).

## Install

```sh
npm install git+ssh://git@github.com/revechatmobile/react-native-revechat-stc-uat.git#main
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
- Needs the Android SDK 3.4.6 or later and an iOS SDK that includes font support (ask ReveChat for the version for your server); older SDKs ignore the option.

### API

| Function | Platform | Description |
|---|---|---|
| `startChat({ accountId, name?, email?, phone?, language?, font? })` | Android, iOS | Opens the chat screen. |
| `setDeviceToken(token)` | Android, iOS | Passes the push token: FCM on Android, APNs (hex string) on iOS. Call again when it refreshes. |
| `handlePushMessage(data)` | Android | Hands an FCM data message to the SDK, which shows the chat notification. No-op on iOS. |
| `setLogEnabled(enabled)` | Android | No-op on iOS. |
| `clearAccountData(accountId)` | Android, iOS | Deletes the chat history and visitor identity stored for one account. `startChat` with another `accountId` switches to that account's own data automatically. Android SDK 3.4.6 or later. |
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

This package already uses the STC UAT Android SDK (`3.4.6_stc_uat`), so you do not need to set a version. To use another one, set it in `android/gradle.properties`:

```properties
ReveChat_sdkVersion=3.4.6_stc_uat
```

## iOS setup

The wrapper's podspec depends on the `ReveChatSDK` pod, so `pod install` brings in the SDK. Do not add a
`pod 'ReveChatSDK'` line yourself.

The default is **`3.1.0-stc-uat`**, the STC UAT build of ReveChatSDK 3.1.0 (it connects to
`chatbot-uat.stc.com.kw`). It is an XCFramework with device and simulator (arm64, x86_64) slices whose only dependency
is `WebRTC-lib`, so **the Podfile needs no edits for ReveChat**: no hooks, no `ENV` flags. It works with
`use_frameworks! :linkage => :static` or `:dynamic` and with React Native's prebuilt dependencies. Minimum iOS 15.0.

```sh
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
  itself. Anything beyond the token (showing or opening chat from a notification) follows the ReveChat iOS guide and is
  not wrapped yet.
- **Not verified:** `handlePushMessage` is wired to the SDK's `PushMessageProcessor`, the same calls the native guide
  makes from a `FirebaseMessagingService`. Receiving a real FCM push end to end has not been tested.

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
| `pod install`: "React Native requires Xcode >= 16.1" | React Native 0.86 needs Xcode 16.1 or later (macOS 14.5 or later). |

## Verified

- Android: React Native 0.88.1 with the New Architecture, SDK 3.4.6_stc_uat, debug and release builds, run on a
  physical Android 15 device (the chat screen opens).
- iOS: React Native 0.86.2 (example app, New Architecture, Hermes, static frameworks, prebuilt React Native
  dependencies), ReveChatSDK `3.1.0-stc-uat` from CocoaPods trunk, Xcode 27.2, CocoaPods 1.16.2, iPhone 17 simulator.
