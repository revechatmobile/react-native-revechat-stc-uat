import { NativeEventEmitter, NativeModules, Platform } from 'react-native';

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
  /**
   * ID of the chat widget to use, for example the web widget's ID. Leave it out to use the account's default widget.
   * Android SDK 3.4.6 or later (the same option on iOS needs an SDK with widget ID support).
   */
  widgetId?: string;
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

export type ReveChatEnvironment = 'production' | 'uat';

type ReveChatNative = {
  startChat(options: Required<Omit<StartChatOptions, 'font'>> & { font: Required<FontOptions> }): Promise<void>;
  setDeviceToken(token: string): Promise<void>;
  clearAccountData(accountId: string): Promise<void>;
  logout(): Promise<void>;
  getUnreadCount(): Promise<number>;
  setEnvironment(environment: ReveChatEnvironment): Promise<void>;
  handlePushMessage(data: Record<string, string>): Promise<void>;
  setLogEnabled(enabled: boolean): Promise<void>;
  setServiceNotification(title: string, content: string): Promise<void>;
  getPendingNotificationTap(): Promise<NotificationTapEvent | null>;
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
    widgetId: options.widgetId ?? '',
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
 * STC build only: chooses the chat server, `'production'` (the default) or `'uat'`. Call it before `startChat`.
 * The choice is saved by the SDK, and the chat data of each environment is kept apart. Switching while a chat is open
 * closes that chat. Needs an STC SDK build with the switch (Android and iOS); rejects with `E_UNSUPPORTED` otherwise.
 */
export async function setEnvironment(environment: ReveChatEnvironment): Promise<void> {
  if (!isSupported) {
    return;
  }
  return native().setEnvironment(environment);
}

/**
 * Logs the visitor out. Closes the chat and clears the chat history, the visitor id and the visitor's saved details
 * stored on this phone, so the next `startChat` creates a new visitor. Call it when the user of your app logs out,
 * then pass the next user's details to `startChat`.
 * Needs a ReveChat SDK with logout (Android 3.4.7 or later, iOS with `clearDataForAccount:`); rejects with
 * `E_UNSUPPORTED` otherwise.
 */
export async function logout(): Promise<void> {
  if (!isSupported) {
    return;
  }
  return native().logout();
}

/**
 * Messages from the agent or bot that arrived while the chat screen was not open: for a badge on your own chat button.
 * Reset to 0 when the chat opens and deleted by `logout()`. Resolves 0 on an SDK without the counter (Android 3.4.8 or
 * later, an iOS SDK with `unreadMessageCount`).
 */
export async function getUnreadCount(): Promise<number> {
  if (!isSupported) {
    return 0;
  }
  return native().getUnreadCount();
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
  getUnreadCount,
};
export default ReveChat;

export type BotStartEvent = { botId: string; sessionId: string };
export type WebHookEvent = { script: string };
export type UnreadCountEvent = { count: number };

/**
 * iOS: the user tapped a notification. Your app passes taps on from its notification delegate (see the README).
 * - `message`: an agent message the SDK showed while the chat screen was closed or the app was in the background
 * - `chatStarted`: an agent picked up the chat while the chat screen was closed
 * - `call`: an agent call while the app was in the background
 * - `remote`: a push from APNs; ReveChat's and your own look alike here, so decide from `data` (the full payload)
 * - `other`: one of your app's own local notifications
 */
export type NotificationTapEvent = {
  kind: 'message' | 'chatStarted' | 'call' | 'remote' | 'other';
  /** The notification request's identifier. */
  identifier: string;
  /** The notification's `userInfo`; for a remote push, the whole payload. Empty for the SDK's local notifications. */
  data: Record<string, unknown>;
};

type ReveChatEventMap = {
  /** The bot conversation started: use `botId` and `sessionId` for your own login call. */
  botStart: BotStartEvent;
  /** The bot asked the app to run a webhook; `script` is the script text from the server. */
  webHook: WebHookEvent;
  /** The bot conversation finished. */
  botFinished: Record<string, never>;
  /** The chat screen came to the front. The unread count is already 0. */
  chatOpened: Record<string, never>;
  /** The chat screen left the front: closed, or the app went to the background. */
  chatClosed: Record<string, never>;
  /** The number of messages that arrived while the chat screen was not open changed. */
  unreadCount: UnreadCountEvent;
  /** iOS only: the user tapped a notification. Call `startChat` to open the chat. */
  notificationTap: NotificationTapEvent;
};

const EVENT_NAMES: Record<keyof ReveChatEventMap, string> = {
  botStart: 'ReveChatBotStart',
  webHook: 'ReveChatWebHook',
  botFinished: 'ReveChatBotFinished',
  chatOpened: 'ReveChatOpened',
  chatClosed: 'ReveChatClosed',
  unreadCount: 'ReveChatUnreadCount',
  notificationTap: 'ReveChatNotificationTap',
};

let emitter: NativeEventEmitter | undefined;

// notificationTap listeners. The native side keeps a tap until it is taken here, so a tap is not lost while the app
// only listens to other events.
const tapListeners = new Set<(tap: NotificationTapEvent) => void>();
let undeliveredTap: NotificationTapEvent | null = null;

function deliverNotificationTap(): void {
  native()
    .getPendingNotificationTap()
    .then((tap) => {
      const next = tap ?? undeliveredTap;
      if (!next) {
        return;
      }
      // The listener may have been removed while the tap was on its way: keep it for the next one.
      undeliveredTap = tapListeners.size === 0 ? next : null;
      tapListeners.forEach((listener) => listener(next));
    })
    .catch(() => {});
}

/**
 * Listens to chat events from the native SDK. Returns a function that removes the listener.
 * The bot events only fire after `startChat` has been called.
 *
 * `notificationTap` (iOS): add it once when your app starts. A tap that arrived before (for example the tap that
 * launched the app) is delivered to it right away.
 */
export function addChatListener<K extends keyof ReveChatEventMap>(
  event: K,
  listener: (payload: ReveChatEventMap[K]) => void
): () => void {
  if (!isSupported) {
    return () => {};
  }
  if (!emitter) {
    emitter = new NativeEventEmitter(NativeModules.ReveChat);
  }
  if (event === 'notificationTap') {
    if (Platform.OS !== 'ios') {
      return () => {};
    }
    // Wrapped so that adding the same function twice gives two independent registrations.
    const tapListener = (tap: NotificationTapEvent) => (listener as (payload: NotificationTapEvent) => void)(tap);
    tapListeners.add(tapListener);
    const signal = emitter.addListener(EVENT_NAMES[event], deliverNotificationTap);
    deliverNotificationTap();
    return () => {
      tapListeners.delete(tapListener);
      signal.remove();
    };
  }
  const subscription = emitter.addListener(EVENT_NAMES[event], listener as (payload: unknown) => void);
  return () => subscription.remove();
}
