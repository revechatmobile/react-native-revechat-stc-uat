# ReveChat for React Native: plug and play integration

Add live chat to an existing React Native app in about 15 minutes. Do the steps in order; each one is a copy and paste.
`startChat()` opens the ReveChat SDK's own native chat screen (Android and iOS). There is no chat UI to build.

**You need from ReveChat:** your **Account ID** (for example `2088935`).

**SDK versions:** Android `3.4.8_stc`, iOS `ReveChatSDK 3.1.0-stc-uat`. Each one connects to both the STC production and UAT
servers; see *Production or UAT* below.

Works with React Native 0.73 or later, New Architecture and Hermes included. Not for Expo Go (use a development build).

---

## Step 1. Install

```sh
npm install git+ssh://git@github.com/revechatmobile/react-native-revechat-stc-uat.git#v0.1.1
```

Autolinking does the rest. There is nothing to add to `MainApplication` or `AppDelegate`.

---

## Step 2. Android (4 edits)

**2.1 `android/app/build.gradle`**: add inside `android { }`:

```gradle
buildFeatures {
    dataBinding true
}
```

**2.2 `android/build.gradle`**: make sure the `ext` block has at least these values:

```gradle
minSdkVersion = 24
compileSdkVersion = 36
targetSdkVersion = 36
```

**2.3 `android/gradle.properties`**: add the SDK version:

```properties
ReveChat_sdkVersion=3.4.8_stc
```

**2.4 `android/app/src/main/AndroidManifest.xml`**: set `singleTop` on `MainActivity`, so the user returns to an open
chat from the launcher icon. With `singleTask`, Android closes
the chat screen when the app is reopened from the launcher icon, and the customer opens the chat again.

```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTop"
    ... >
```

The SDK's FileProviders use their own names (for example `${applicationId}.revechatsdk.provider`), so they do not clash
with other libraries. For a text-chat app without calls, see the README, *Text chat only*.

Run Gradle with JDK 17.0.14 or later (21 works too). Done with Android.

---

## Step 3. iOS (1 edit)

**3.1 Install the pods.** Nothing to add to the Podfile: the wrapper brings in the ReveChat iOS SDK
(`ReveChatSDK 3.1.0-stc-uat`, the STC build) and its only dependency, `WebRTC-lib`. Keep your existing
`use_frameworks!` setting (static or dynamic); no hooks or `ENV` flags are needed.

```sh
cd ios && pod install
```

**Installed `3.1.0-stc-uat` before 26 Nov 2026?** The SDK behind that version was updated on 26 Nov 2026 under the same
version number, and CocoaPods keeps using its cached download. Clear it once, then install again:

```sh
pod cache clean ReveChatSDK --all
rm -rf ios/Pods/ReveChatSDK
cd ios && pod install
```

Then clean the build in Xcode (*Product → Clean Build Folder*) and rebuild. The updated SDK has the production / UAT
switch: it connects to **STC production** unless you call `setEnvironment('uat')` before `startChat`.

**Xcode 27 only:** Xcode 27 rejects any pod target whose deployment target is below 15.0. `react_native_post_install`
raises the pods' own targets but not their resource-bundle targets (for example `RNCAsyncStorage_resources`, 13.4). If
the build stops with `IPHONEOS_DEPLOYMENT_TARGET is set to 13.4`, add this at the end of the `post_install` block in
`ios/Podfile`, after `react_native_post_install(...)`, and run `pod install` again. It is not caused by ReveChat
(`ReveChatSDK` and `WebRTC-lib` declare 15.0).

```ruby
installer.pods_project.targets.each do |target|
  target.build_configurations.each do |config|
    current = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f
    if current > 0 && current < 15.0
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
```

**3.2 `ios/YourApp/Info.plist`**: add these four keys inside `<dict>` (iOS closes the app without them). Change the wording to
suit your app.

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

For voice and video calls and push, also enable **Push Notifications** and **Background Modes** (Voice over IP, Audio)
under Signing & Capabilities in Xcode.

**3.3 Xcode 27 only: scene life cycle.** An app built with the iOS 27 SDK must use the UIScene life cycle, or iOS
does not launch it on a device (`UIScene life cycle is required for apps built with this SDK`, Apple TN3187). The
simulator may still launch it, so test on a phone. This applies to every app, not only to ReveChat. If your
`AppDelegate` still creates the window and starts React Native, move that into a scene delegate.

---

## Step 4. Add the chat button

Copy this file into your app and use `<ChatButton />` anywhere. Replace the account ID.

```tsx
// ChatButton.tsx
import React from 'react';
import { Alert, Button, I18nManager } from 'react-native';
import { startChat } from 'react-native-revechat';

const ACCOUNT_ID = '2088935'; // your ReveChat account ID

type Props = { name?: string; email?: string; phone?: string };

export default function ChatButton({ name, email, phone }: Props) {
  const open = async () => {
    try {
      await startChat({
        accountId: ACCOUNT_ID,
        name,
        email,
        phone,
        // Arabic and right-to-left when your app is right-to-left, otherwise the device language.
        language: I18nManager.isRTL ? 'ar' : undefined,
      });
    } catch (e) {
      Alert.alert('Chat', (e as Error).message);
    }
  };
  return <Button title="Chat with us" onPress={open} />;
}
```

Now **rebuild the app** (a JavaScript reload is not enough, native code was added):

```sh
npx react-native run-android
npx react-native run-ios
```

Tap the button: the ReveChat chat screen opens. That is the whole integration.

---

## Production or UAT

The chat connects to **production** unless you choose otherwise. To use UAT, call this before `startChat`:

```ts
import { setEnvironment } from 'react-native-revechat';

await setEnvironment(__DEV__ ? 'uat' : 'production'); // 'uat' for testing, 'production' for your users
```

The SDK saves the choice and keeps each environment's chat data apart. Switching while a chat is open closes that chat. Test builds should always set `'uat'`: on production your test chats
reach real agents.

---

## Log out

Call `logout()` when your user logs out, so the next person on the phone starts a new chat and cannot see the previous
messages.

```ts
import { logout } from 'react-native-revechat';

await logout();                       // then clear your own session
// next time: startChat with the new user's name, email and phone
```

It closes the open chat, and deletes the chat history, visitor and session IDs, saved name, email and phone, and the files
the SDK stored (on Android including files downloaded from the agent; files saved to the shared Downloads or Pictures
folders stay). The account ID, push token and chat sound setting are kept. It clears the server environment now selected.

---

## Choose the bot (widget ID)

Pass the widget ID your website uses:

```ts
await startChat({ accountId: ACCOUNT_ID, widgetId: 'your-widget-id' });
```

---

## Events and callbacks

`addChatListener(event, listener)` returns a function that removes the listener.

| Event | When | Data |
|---|---|---|
| `botStart` | A bot conversation was created or is running | `{ botId, sessionId }` |
| `webHook` | The server asks the app to run a script (the customer login step) | `{ script }` |
| `botFinished` | The chat ended | none |
| `chatOpened` | The chat screen came to the front (unread count is 0) | none |
| `chatClosed` | The chat screen closed, or the app went to the background | none |
| `unreadCount` | The number of messages received while the chat was not open changed | `{ count }` |
| `notificationTap` | iOS only: the customer tapped a notification | see *iOS: notification banners* |

Register once, for example in your root component:

```tsx
import { useEffect, useState } from 'react';
import { addChatListener, getUnreadCount } from 'react-native-revechat';

export function useReveChatEvents() {
  const [unread, setUnread] = useState(0);

  useEffect(() => {
    getUnreadCount().then(setUnread);
    const remove = [
      addChatListener('botStart', ({ botId, sessionId }) => { /* keep the IDs */ }),
      addChatListener('webHook', ({ script }) => { /* see Verified customer */ }),
      addChatListener('botFinished', () => {}),
      addChatListener('chatOpened', () => {}),
      addChatListener('chatClosed', () => {}),
      addChatListener('unreadCount', ({ count }) => setUnread(count)),
    ];
    return () => remove.forEach((stop) => stop());
  }, []);

  return unread; // for a badge on your chat button
}
```

---

## Verified customer

The SDK does not take your login token. `name`, `email` and `phone` are plain details, not proof of identity. Your app
logs the customer in to the bot the same way your website does:

1. `startChat` with your `widgetId`.
2. The bot starts and sends the `webHook` event with a script like
   `functionName({"chatbot_id":"...","session_id":"..."});`.
3. Your app reads the two IDs and calls **your own** login webhook with the customer's token.
4. The bot continues, knowing who the customer is.

```ts
addChatListener('webHook', ({ script }) => {
  const json = script.slice(script.indexOf('(') + 1, script.lastIndexOf(')'));
  try {
    const { chatbot_id, session_id } = JSON.parse(json);
    if (chatbot_id && session_id) {
      myApi.chatbotLogin({ chatbotId: chatbot_id, sessionId: session_id }); // your server call
    }
  } catch {
    // another kind of script
  }
});
```

The `session_id` to send is the one in the `webHook` script.

---

## Optional

### Pass the logged-in user
Pass `name`, `email` and `phone` from your login so the visitor does not fill the SDK's pre-chat form. Leave a field out to
let the SDK ask for it.

### Force a language
```ts
await startChat({ accountId: ACCOUNT_ID, language: 'ar' });   // Arabic, right-to-left
await startChat({ accountId: ACCOUNT_ID, language: 'en' });   // English
await startChat({ accountId: ACCOUNT_ID });                   // follow the device language
```
Arabic (`ar`, also `he`, `fa`, `ur`) turns the chat screens right-to-left. It does not change your own app. On iOS this is
the only way to get Arabic unless your app declares `ar` in `CFBundleLocalizations`.

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
system font, see *If something goes wrong* below.

- Leave `font` out to use the system font. Use `.ttf` or `.otf` files.
- Pass the same value on every `startChat` call. A call without `font` goes back to the system font for screens opened afterwards.
- Text the font has no letters for (for example Arabic in a Latin-only font) is shown in the system font.
- Check the font's licence allows embedding in an app.
- Included in `3.4.8_stc` (Android) and `3.1.0-stc-uat` (iOS).

### Light / dark background
Your app chooses the background of the chat screens. Only the neutral parts change (the screen background, white cards and
forms, the received-message bubbles and the dark text on them). The theme colour from the widget settings in the ReveChat
portal still drives the toolbar, your sent bubbles, buttons and links, exactly as before.

```ts
await startChat({ accountId: ACCOUNT_ID, backgroundTheme: 'dark' });                    // 'light' | 'dark' | 'system'
await startChat({ accountId: ACCOUNT_ID, backgroundColor: '#101820' });                 // an exact colour from your brand guide
await startChat({ accountId: ACCOUNT_ID });                                             // unchanged: the SDK's own light look
```

- **`backgroundTheme`:** `'light'` is the SDK's own look and the default. `'dark'` uses a dark palette. `'system'` follows the phone's light/dark setting.
- **`backgroundColor`:** a hex colour (`'#RRGGBB'`). It wins over `backgroundTheme`. The card, bubble and text colours are derived from it: a dark colour gives light text, a light colour gives dark text.
- **Nothing passed:** the chat looks exactly as before. It does not follow your app's or the phone's dark mode.
- The camera, photo, video and document viewers keep their own dark design.
- If you call `startChat` again with another value while a chat is open, the open chat screens update at once.
- Choose a widget theme colour that is readable on your background: the SDK does not change it.
- Included in `3.4.8_stc` (Android) and `3.1.0-stc-uat` (iOS).

**Native apps** (without React Native) call the SDK directly:

- Android: `ReveChat.setBackgroundTheme(ReveChatBackground.Mode.DARK)`, `ReveChat.setBackgroundColor(Color.parseColor("#101820"))`, `ReveChat.resetBackground()`.
- iOS: `[ReveChatBackground setBackgroundTheme:ReveChatBackgroundThemeDark]`, `[ReveChatBackground setBackgroundColorHex:@"#101820"]`, `[ReveChatBackground reset]`.

### Push notifications
With `@react-native-firebase/messaging`:

```ts
import messaging from '@react-native-firebase/messaging';
import { Platform, PermissionsAndroid } from 'react-native';
import { setDeviceToken, handlePushMessage } from 'react-native-revechat';

// Android 13+: allow notifications
if (Platform.OS === 'android') {
  await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS);
}

// Send the token on start and whenever it refreshes
const token = Platform.OS === 'ios' ? await messaging().getAPNSToken() : await messaging().getToken();
if (token) await setDeviceToken(token);
messaging().onTokenRefresh((t) => setDeviceToken(t));

// Android: let the SDK show ReveChat notifications
messaging().onMessage((m) => handlePushMessage(m.data ?? {}));
messaging().setBackgroundMessageHandler(async (m) => handlePushMessage(m.data ?? {}));
```

- Call `setDeviceToken` **before** `startChat`. On iOS the token is sent when the chat connects.
- The SDK does not register its own `FirebaseMessagingService`, so OneSignal and React Native Firebase stay in control.
- A ReveChat message has the data key `requestType` with `chat_message`, `chat_started`, `session_ended`,
  `auto_resolve_message` or `voip_call`, and its content in `body`. Pass only those to `handlePushMessage`.

### iOS: notification banners and opening the chat from a tap
After the visitor closes the chat screen (or while the app is in the background with the chat open), the iOS SDK posts
local notifications for agent messages, "chat started" and incoming calls. Two additions make them work like the
Android ones:

**1. `AppDelegate.swift`** — show them while the app is open, and pass taps to the wrapper. Set the delegate in
`didFinishLaunchingWithOptions` (before launch ends, so the tap that launched the app is delivered too):

```swift
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let id = notification.request.identifier
    let isReveChat = id.hasPrefix("ReveChatLanding_") || id.hasPrefix("ReveChatAgent_")
      || id.hasPrefix("ReveChatIncomingCall_") || id == "OutsideNotification"
    completionHandler(isReveChat ? [.banner, .list, .sound] : [])  // keep your own rule for other notifications
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    NotificationCenter.default.post(name: Notification.Name("ReveChatNotificationTapped"), object: response)
    completionHandler()
  }
}
```

If Firebase Messaging or another library already owns the notification delegate, add the same two rules where that
library hands you foreground notifications and taps.

**2. JavaScript** — open the chat when a ReveChat notification is tapped. Add the listener once, when the visitor's
details are known; a tap that launched the app is delivered to it as soon as it is added:

```ts
import { addChatListener, startChat } from 'react-native-revechat';

useEffect(
  () =>
    addChatListener('notificationTap', (tap) => {
      // 'message', 'chatStarted', 'call': ReveChat's own. 'remote': an APNs push, check tap.data. 'other': yours.
      if (tap.kind !== 'other') {
        startChat({ accountId: 'YOUR_ACCOUNT_ID', name, email, phone });
      }
    }),
  []
);
```

`startChat` does nothing if the chat is already open. With the app in the background the SDK can post these only for
the few seconds before iOS suspends the app; after that only the ReveChat server's push reaches the visitor. Details
(identifiers, remote pushes) are in the README, *iOS: showing ReveChat notifications while the app is open*.

### Several accounts
Call `startChat` with a different `accountId` and the SDK switches to that account's own data: each account keeps its
own chat history and visitor identity on the phone, and one account never sees another's. Use `clearAccountData(accountId)`
to remove an account's data (for example on logout). Nothing else is needed.

### API
| Function | Platform | Purpose |
|---|---|---|
| `startChat({ accountId, name?, email?, phone?, widgetId?, language?, font?, backgroundTheme?, backgroundColor? })` | Android, iOS | Opens the chat. Rejects if `accountId` is empty. |
| `setDeviceToken(token)` | Android, iOS | FCM token on Android, APNs token on iOS. |
| `handlePushMessage(data)` | Android | Shows the ReveChat notification for an FCM message. |
| `setLogEnabled(enabled)` | Android | SDK logging on or off. |
| `clearAccountData(accountId)` | Android, iOS | Deletes the history and visitor identity stored for one account (for example on logout). Android `3.4.8_stc`, iOS `3.1.0-stc-uat`. |
| `setEnvironment('production' \| 'uat')` | Android, iOS | Chooses the STC server. See *Production or UAT*. |
| `logout()` | Android, iOS | Closes the chat and clears the visitor's local history and identity. Call it when your app's user logs out. |
| `addChatListener(event, listener)` | Android, iOS | `'botStart'`, `'webHook'`, `'botFinished'` (bot login), `'chatOpened'`, `'chatClosed'`, `'unreadCount'` (chat screen and unread badge) and, on iOS, `'notificationTap'`. Returns a function that removes the listener. |
| `setServiceNotification({ title, content })` | Android | Text of the chat service notification. |
| `getUnreadCount()` | Android, iOS | Messages that arrived while the chat screen was closed, for a badge on your chat button. |

Calls that do not apply to the platform resolve without error, so you need no `Platform.OS` checks.

---

## Check it works

1. Tap the button: pre-chat form (if your account has one), then the chat.
2. Send a message and get a reply.
3. Attach a photo (the permission prompt appears the first time).
4. Press Back, open the chat again: the conversation is still there.
5. With `language: 'ar'`: the screens mirror and the text is Arabic.
6. iOS: press Back, have the agent send a message: a banner appears; tapping it opens the chat.

---

## If something goes wrong

| You see | Fix |
|---|---|
| `the native module 'ReveChat' was not found` | Rebuild the app (and `pod install` on iOS). |
| Android: crash when the chat opens, `DataBinderMapperImpl` | Step 2.1 (`dataBinding true`). |
| Android: `PKIX path building failed` | Run Gradle on JDK 17.0.14+ or 21. |
| Android: `Duplicate class android.support.v4...` | Add `android.enableJetifier=true` to `gradle.properties` (SDK 3.4.0 only). |
| Android: tapping the launcher icon loses the open chat | Step 2.4 (`singleTop`). |
| The chat still uses the system font | Android: the file must be in `android/app/src/main/assets/fonts/` and the app rebuilt. iOS: the file must be listed in the target's *Build Phases → Copy Bundle Resources*. On both: pass the **file name** (`Cairo-Regular.ttf`), not the font family name, and use an SDK version with font support (older SDKs ignore `font`). The Android log line `ReveChatFont: font file not found in assets` and the iOS log line `font file not found in the app bundle` name the file that was not found. |
| iOS: crash at launch, `Symbol not found: ...hermes3cdp11CDPDebugAPI...` | A Release Hermes is left in `ios/Pods` from an earlier Release build. `rm -rf ios/Pods/hermes-engine && pod install`. Not ReveChat-specific. |
| iOS `pod install`: `Unable to find a specification for ReveChatSDK` | `pod repo update`, then `pod install`. |
| iOS: app closes when the chat uses the camera, microphone or photos | Step 3.2 (the four `Info.plist` keys). |
| iOS build: `IPHONEOS_DEPLOYMENT_TARGET is set to 13.4, but the range of supported deployment target versions is 15.0 to ...` | Step 3.1, the Xcode 27 `post_install` addition. |
| iOS device: the app does not start, `UIScene life cycle is required for apps built with this SDK` | Step 3.3 (scene delegate). |
| iOS: no banner for agent messages after closing the chat | Step *iOS: notification banners* (the `AppDelegate` delegate). If the notification is not in Notification Center either, the cached SDK is older than the fix: clear it as in the next row. |
| iOS: `setEnvironment`, `logout`, the bot events or notifications after closing the chat do nothing, or the chat still connects to UAT only | The `3.1.0-stc-uat` SDK downloaded before 26 Nov 2026 is cached on your Mac. Clear it as in Step 3.1 (`pod cache clean ReveChatSDK --all && rm -rf ios/Pods/ReveChatSDK && cd ios && pod install`), then *Clean Build Folder* and rebuild. |
| iOS: `font`, `backgroundTheme` and `clearAccountData` have no effect | An older download of `ReveChatSDK 3.1.0-stc-uat` is cached on your Mac. `pod cache clean ReveChatSDK --all && rm -rf ios/Pods/ReveChatSDK && cd ios && pod install`, then rebuild. |
| iOS: `unrecognized selector` after rebuilding a local SDK | Delete `<DerivedData>/Build/Products/<config>-iphonesimulator/XCFrameworkIntermediates/ReveChatSDK` and the app's `Frameworks/ReveChatSDK.framework`, rebuild. |
| iOS `pod install`: "React Native requires Xcode >= 16.1" | React Native 0.86 needs Xcode 16.1 or later. |
| The chat stays English on an Arabic device | Pass `language: 'ar'`. |
| Messages cannot be sent | The SDK build points to another server than your account. Ask ReveChat for the build for your server. |

---

## Compatibility and status

| | Android | iOS |
|---|---|---|
| React Native | 0.86.2 (New Architecture, Hermes) | 0.86.2 (New Architecture, Hermes, static frameworks, prebuilt RN dependencies) |
| Minimum OS | Android 7.0 (`minSdkVersion` 24) | iOS 15.0 |
| SDK version | `3.4.8_stc` | `3.1.0-stc-uat` |

**Not supported:** runtime theming of the widget colours from the app (only the background can be chosen), Huawei HMS push.

A working reference app is in `example/` (React Native 0.86.2, a form that is remembered between launches, a chat language dropdown, a chat background dropdown and colour field, a custom font switch, an STC production / UAT switch, log out, and on iOS
notification banners with tap-to-open in `AppDelegate.swift`).
