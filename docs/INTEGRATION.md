# ReveChat for React Native: plug and play integration

Add live chat to an existing React Native app in about 15 minutes. Do the steps in order; each one is a copy and paste.
`startChat()` opens the ReveChat SDK's own native chat screen (Android and iOS). There is no chat UI to build.

**You need from ReveChat:** your **Account ID** (for example `2088935`), and the **SDK version for your server**
(Android version number; on iOS the wrapper already defaults to `3.1.0-stc-uat`). Use exactly what ReveChat gives you.

Works with React Native 0.73 or later, New Architecture and Hermes included. Not for Expo Go (use a development build).

---

## Step 1. Install

```sh
npm install git+ssh://git@github.com/revechatmobile/react-native-revechat-stc-uat.git#main
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

**2.3 `android/gradle.properties`**: nothing to add. The package already uses the STC UAT Android SDK `3.4.6_stc_uat`. Only set the version if ReveChat gives you a different one:

```properties
ReveChat_sdkVersion=3.4.6_stc_uat
```

**2.4 `android/app/src/main/AndroidManifest.xml`**: add the `tools` namespace to `<manifest>`, and two attributes to
`<application>` (a merge conflict on `usesCleartextTraffic` otherwise), and set `singleTop` on `MainActivity` so the user
returns to an open chat from the launcher icon:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <application
        android:usesCleartextTraffic="${usesCleartextTraffic}"
        tools:replace="android:usesCleartextTraffic"
        ... >

        <activity
            android:name=".MainActivity"
            android:launchMode="singleTop"
            ... >
```

Run Gradle with JDK 17.0.14 or later (21 works too). Done with Android.

---

## Step 3. iOS (1 edit)

**3.1 Install the pods.** Nothing to add to the Podfile: the wrapper brings in the ReveChat iOS SDK
(`ReveChatSDK 3.1.0-stc-uat`, the STC UAT build) and its only dependency, `WebRTC-lib`. Keep your existing
`use_frameworks!` setting (static or dynamic); no hooks or `ENV` flags are needed.

```sh
cd ios && pod install
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
- Needs the Android SDK 3.4.6 or later and an iOS SDK that includes font support (ask ReveChat for the version for your server); older SDKs ignore the option.

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
- Needs an SDK version with background support on Android and iOS (ask ReveChat for the version for your server); older SDKs ignore both options.

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

### Several accounts
Call `startChat` with a different `accountId` and the SDK switches to that account's own data: each account keeps its
own chat history and visitor identity on the phone, and one account never sees another's. Use `clearAccountData(accountId)`
to remove an account's data (for example on logout). Nothing else is needed.

### API
| Function | Platform | Purpose |
|---|---|---|
| `startChat({ accountId, name?, email?, phone?, language?, font?, backgroundTheme?, backgroundColor? })` | Android, iOS | Opens the chat. Rejects if `accountId` is empty. |
| `setDeviceToken(token)` | Android, iOS | FCM token on Android, APNs token on iOS. |
| `handlePushMessage(data)` | Android | Shows the ReveChat notification for an FCM message. |
| `setLogEnabled(enabled)` | Android | SDK logging on or off. |
| `clearAccountData(accountId)` | Android, iOS | Deletes the history and visitor identity stored for one account (for example on logout). Android SDK 3.4.6 or later. |
| `setServiceNotification({ title, content })` | Android | Text of the chat service notification. |

Calls that do not apply to the platform resolve without error, so you need no `Platform.OS` checks.

---

## Check it works

1. Tap the button: pre-chat form (if your account has one), then the chat.
2. Send a message and get a reply.
3. Attach a photo (the permission prompt appears the first time).
4. Press Back, open the chat again: the conversation is still there.
5. With `language: 'ar'`: the screens mirror and the text is Arabic.

---

## If something goes wrong

| You see | Fix |
|---|---|
| `the native module 'ReveChat' was not found` | Rebuild the app (and `pod install` on iOS). |
| Android: crash when the chat opens, `DataBinderMapperImpl` | Step 2.1 (`dataBinding true`). |
| Android: `Manifest merger failed ... usesCleartextTraffic` | Step 2.4 (`tools:replace`). |
| Android: `PKIX path building failed` | Run Gradle on JDK 17.0.14+ or 21. |
| Android: `Duplicate class android.support.v4...` | Add `android.enableJetifier=true` to `gradle.properties` (SDK 3.4.0 only). |
| Android: tapping the launcher icon loses the open chat | Step 2.4 (`singleTop`). |
| The chat still uses the system font | Android: the file must be in `android/app/src/main/assets/fonts/` and the app rebuilt. iOS: the file must be listed in the target's *Build Phases → Copy Bundle Resources*. On both: pass the **file name** (`Cairo-Regular.ttf`), not the font family name, and use an SDK version with font support (older SDKs ignore `font`). The Android log line `ReveChatFont: font file not found in assets` and the iOS log line `font file not found in the app bundle` name the file that was not found. |
| iOS: crash at launch, `Symbol not found: ...hermes3cdp11CDPDebugAPI...` | A Release Hermes is left in `ios/Pods` from an earlier Release build. `rm -rf ios/Pods/hermes-engine && pod install`. Not ReveChat-specific. |
| iOS `pod install`: `Unable to find a specification for ReveChatSDK` | `pod repo update`, then `pod install`. |
| iOS: app closes when the chat uses the camera, microphone or photos | Step 3.2 (the four `Info.plist` keys). |
| iOS: `unrecognized selector` after rebuilding a local SDK | Delete `<DerivedData>/Build/Products/<config>-iphonesimulator/XCFrameworkIntermediates/ReveChatSDK` and the app's `Frameworks/ReveChatSDK.framework`, rebuild. |
| iOS `pod install`: "React Native requires Xcode >= 16.1" | React Native 0.86 needs Xcode 16.1 or later. |
| The chat stays English on an Arabic device | Pass `language: 'ar'`. |
| Messages cannot be sent | The SDK build points to another server than your account. Ask ReveChat for the build for your server. |

---

## Compatibility and status

| | Android | iOS |
|---|---|---|
| React Native | Verified on 0.86.2 (New Architecture, Hermes) | Verified on 0.86.2 (New Architecture, Hermes, static frameworks, prebuilt RN dependencies) |
| Minimum OS | Android 7.0 (`minSdkVersion` 24) | iOS 15.0 |
| Verified on | Physical Android 15 device | iPhone 17 simulator, Xcode 27.2 |
| SDK version | `3.4.6_stc_uat` | `3.1.0-stc-uat` |

**Not available yet:** runtime theming of the widget colours from the app (only the background can be chosen), Huawei HMS push.

A working reference app is in `example/` (React Native 0.86.2, a form that is remembered between launches, a chat language dropdown, a chat background dropdown and colour field, a custom font switch).
