# react-native-revechat example

Sample app for the `react-native-revechat` package, on React Native 0.86.2 (New Architecture, Hermes).
It asks for account ID, name, email and phone, and passes them to the native ReveChat SDK on Android and iOS.
It uses the package from the parent folder (`"react-native-revechat": "file:.."`).

```sh
npm install
npm start                # Metro
npm run android          # needs JDK 21 and the Android SDK
cd ios && bundle install && bundle exec pod install && cd .. && npm run ios   # needs a Mac
```

- Android: compile/target SDK 36, min SDK 24, Kotlin 2.1.20, NDK 28.2. SDK version override:
  `-PReveChat_sdkVersion=3.4.6_stc_uat` (Jetifier in `gradle.properties` is only needed for 3.4.0).
- iOS: deployment target 15.1, static frameworks (`USE_FRAMEWORKS=dynamic` to compare), ReveChatSDK `3.1.0-stc-uat`
  from CocoaPods through the wrapper's podspec. No ReveChat hooks in the Podfile. Runs on the simulator.
- The "Chat language" dropdown (System, English, Arabic) is passed to the SDK as `language`; the host app itself stays left-to-right.
- The "Chat background" dropdown (System, Light, Dark) and the optional exact colour field are passed as `backgroundTheme` and `backgroundColor`. Light is the default and leaves the chat as it was.
- The "Custom font (Xarrovv)" switch passes `fonts/Xarrovv.otf` to the SDK. The font file is in `android/app/src/main/assets/fonts/` (Android) and in the iOS app target's *Copy Bundle Resources* (iOS), the two steps every app needs; see "Custom font" in `docs/INTEGRATION.md`.
- The form (account ID, name, email, phone, language, background, font) is remembered between launches.

## Launch mode of `MainActivity`

The example sets `android:launchMode="singleTop"` for `MainActivity` (the React Native template uses `singleTask`).
With `singleTask`, tapping the launcher icon while the chat is open sends the MAIN intent to `MainActivity`, which
clears every activity above it in the task, so the chat screen is destroyed and the app shows its landing page
(ASDK-2413). With `singleTop` the chat screen is still there when the user returns. Host apps that want to come
back to an open chat should do the same.
