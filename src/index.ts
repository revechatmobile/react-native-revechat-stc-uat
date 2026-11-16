import { NativeModules, Platform } from 'react-native';

export type FontOptions = {
  /**
   * Font files for the chat screens. Each value is a file in your app's assets, for example `Cairo-Regular.ttf` or
   * `fonts/Cairo-Regular.ttf` (Android: `android/app/src/main/assets/fonts/`). Only `regular` is required; a missing
   * `medium` or `bold` falls back to `regular`.
   */
  regular: string;
  medium?: string;
  bold?: string;
};

export type StartChatOptions = {
  /** Your ReveChat account ID, for example '1234567'. */
  accountId: string;
  name?: string;
  email?: string;
  phone?: string;
  /**
   * Language of the chat screens, for example 'ar' or 'en'. Arabic also turns the screens right-to-left.
   * Leave it out to follow the device language.
   */
  language?: string;
  /** Font of the chat screens. Leave it out to use the system font. */
  font?: FontOptions;
  /**
   * Background of the chat screens: 'light' (the SDK's own look, default), 'dark' or 'system' (follows the phone).
   * Only the neutral background and the dark text on it change; the theme colour from the widget settings still
   * drives bubbles, toolbar and buttons. Needs an SDK version with background support; older SDKs ignore it.
   */
  backgroundTheme?: 'light' | 'dark' | 'system';
  /** Exact background colour as a hex string, for example '#101820'. It wins over `backgroundTheme`. */
  backgroundColor?: string;
};

export type ServiceNotificationOptions = {
  title: string;
  content: string;
};

type ReveChatNative = {
  startChat(options: Required<Omit<StartChatOptions, 'font'>> & { font: Required<FontOptions> }): Promise<void>;
  setDeviceToken(token: string): Promise<void>;
  clearAccountData(accountId: string): Promise<void>;
  handlePushMessage(data: Record<string, string>): Promise<void>;
  setLogEnabled(enabled: boolean): Promise<void>;
  setServiceNotification(title: string, content: string): Promise<void>;
};

const LINKING_ERROR =
  "react-native-revechat: the native module 'ReveChat' was not found. " +
  'Rebuild the app after installing the package (a JavaScript reload is not enough), ' +
  'and run `pod install` in ios/. Expo Go is not supported; use a development build.';

const isSupported = Platform.OS === 'android' || Platform.OS === 'ios';

function native(): ReveChatNative {
  const module = NativeModules.ReveChat as ReveChatNative | undefined;
  if (!module) {
    throw new Error(LINKING_ERROR);
  }
  return module;
}

/**
 * Opens the ReveChat native chat screen.
 * Rejects if `accountId` is missing or the platform is not Android or iOS.
 */
export async function startChat(options: StartChatOptions): Promise<void> {
  if (!isSupported) {
    throw new Error(`react-native-revechat does not support ${Platform.OS}.`);
  }
  if (!options || typeof options.accountId !== 'string' || options.accountId.trim() === '') {
    throw new Error('react-native-revechat: accountId is required.');
  }
  return native().startChat({
    accountId: options.accountId.trim(),
    name: options.name ?? '',
    email: options.email ?? '',
    phone: options.phone ?? '',
    language: options.language ?? '',
    font: {
      regular: options.font?.regular ?? '',
      medium: options.font?.medium ?? '',
      bold: options.font?.bold ?? '',
    },
    backgroundTheme: options.backgroundTheme ?? 'light',
    backgroundColor: options.backgroundColor ?? '',
  });
}

/**
 * Deletes the chat history, visitor identity and session state the SDK stored on this phone for one account.
 * Use it when the user logs out. Calling `startChat` with a different `accountId` switches to that account's own
 * data automatically (each account keeps its own history); this call is only for removing it.
 * Needs Android SDK 3.4.6 or later and an iOS SDK that has `clearDataForAccount:`; rejects with `E_UNSUPPORTED` otherwise.
 */
export async function clearAccountData(accountId: string): Promise<void> {
  if (!isSupported) {
    return;
  }
  if (typeof accountId !== 'string' || accountId.trim() === '') {
    throw new Error('react-native-revechat: accountId is required.');
  }
  return native().clearAccountData(accountId.trim());
}

/**
 * Passes the push token to the SDK: the FCM registration token on Android, the APNs device token on iOS.
 * Call it again whenever the token refreshes.
 */
export async function setDeviceToken(token: string): Promise<void> {
  if (!isSupported) {
    return;
  }
  return native().setDeviceToken(token);
}

/**
 * Android only: hands an FCM data message to the SDK, which shows the chat notification.
 * Call it from your messaging handler (foreground and background) with `remoteMessage.data`.
 * No-op on iOS.
 */
export async function handlePushMessage(data: Record<string, string>): Promise<void> {
  if (Platform.OS !== 'android') {
    return;
  }
  return native().handlePushMessage(data);
}

/** Android only. No-op on iOS. */
export async function setLogEnabled(enabled: boolean): Promise<void> {
  if (Platform.OS !== 'android') {
    return;
  }
  return native().setLogEnabled(enabled);
}

/** Android only: text of the notification shown while the chat service runs. No-op on iOS. */
export async function setServiceNotification(options: ServiceNotificationOptions): Promise<void> {
  if (Platform.OS !== 'android') {
    return;
  }
  return native().setServiceNotification(options.title, options.content);
}

const ReveChat = {
  startChat,
  setDeviceToken,
  handlePushMessage,
  setLogEnabled,
  setServiceNotification,
};
export default ReveChat;
