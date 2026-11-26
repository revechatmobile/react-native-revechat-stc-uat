# Logout and bot callbacks

How a host app logs a visitor out, and how it learns about the bot conversation (to log the customer in to the bot).
Covers the Android SDK, the iOS SDK and the React Native wrapper.

- [1. Logout](#1-logout)
- [2. Bot callbacks](#2-bot-callbacks)
- [3. Chat screen events](#3-chat-screen-events-opened-closed-unread-count)
- [4. Telling the bot who the customer is](#4-telling-the-bot-who-the-customer-is)
- [5. Notes](#5-notes)

---

## 1. Logout

Call it when the user of your app logs out, so the next person who uses the phone starts a new chat and cannot see the
previous person's messages.

### What it does

| | |
|---|---|
| Closes | the open chat screen, a running call, and the connection to the chat server |
| Deletes | the chat history, the visitor ID, the tab ID and the visitor session ID, the visitor's saved name, email and phone, and the saved session state |
| Keeps | the account ID, the push token and the chat sound setting. Set the widget ID, language, background and font in code as you do before each chat. |

The next time the chat opens, the SDK logs in without a visitor ID and the server answers with a new one, so the visitor
is a new visitor. A new tab ID and visitor session ID are generated as well.

### Android

```java
// when your app's user logs out
ReveChat.logout();

// before the next user opens the chat, set their details again
ReveChat.setVisitorInfo(nextVisitorInfo);
```

```kotlin
ReveChat.logout()
```

- It also clears the visitor details that were saved, so call `setVisitorInfo(...)` again for the next user.
- It also deletes the files the SDK itself left in the app's private storage: copies of files the visitor picked to
  send, captured photos and videos, resized images, the temporary send folder and the files the visitor downloaded
  from the agent (in the app's own media folder). Files saved in the phone's shared
  Downloads or Pictures folders belong to the user and are not deleted.
- In the STC build, `logout()` clears the environment now selected (UAT or production). The other environment's data is
  left alone. `ReveChat.clearDataForAccount(accountId)` clears both.

### iOS

```objc
[ReveChatManager logout];
```

```swift
ReveChatManager.logout()
```

- It stops the chat and deletes the chat history, the visitor, tab and session IDs, and the files the SDK stored for the
  account in use.
- In the STC build it clears the selected environment only. `[ReveChatManager clearDataForAccount:accountId]` clears
  one account in both environments (and works for the account in use too).
- It does nothing when no account has been set yet.

### React Native

```ts
import { logout } from 'react-native-revechat';

await logout();
```

- Android calls `ReveChat.logout()`. iOS calls `+[ReveChatManager logout]`; with an iOS SDK that does not have it, it
  clears the account the app last started a chat on.
- It rejects with `E_UNSUPPORTED` when the native SDK is too old to have a logout.
- Then pass the next user's details to `startChat`.

### Suggested app flow

1. The user taps Log out in your app.
2. Call `logout()` (ReveChat), then clear your own session as usual.
3. A different user logs in and opens the chat: `startChat` / `setVisitorInfo` with their details. The chat starts as a
   new visitor.

---

## 2. Bot callbacks

Three events tell the app about the bot conversation. They are the same on Android, iOS and React Native.

| Event | When | Data |
|---|---|---|
| Bot start | A bot conversation was created or is running | the bot ID and a session ID |
| Webhook | The server asked the app to run a script, which is how the web chat starts the customer login | the script text |
| Finished | The chat ended | none |

### Android

Implement `REVEChatEventListener` and register it. `registerListener` sets your app's main listener (a second call
replaces it, and `unregisterListener()` clears it). To listen from a second place, for example a library, use
`REVEChatEventManager.INSTANCE.addListener(...)` and `removeListener(...)`: every registered listener gets every event
and none replaces another. (`addListener` needs Android SDK 3.4.7 or later.)

```java
public class MainActivity extends AppCompatActivity implements REVEChatEventListener {

    @Override protected void onStart() {
        super.onStart();
        REVEChatEventManager.INSTANCE.registerListener(this);
    }

    @Override protected void onStop() {
        REVEChatEventManager.INSTANCE.unregisterListener();
        super.onStop();
    }

    @Override public void onBotStart(@NonNull String botId, @NonNull String sessionId) {
        // a bot conversation started or is running
    }

    @Override public void onWebHookEvent(String scriptInfo) {
        // scriptInfo looks like: functionName({"chatbot_id":"...","session_id":"..."});
    }

    @Override public void onBotConversationFinished() {
        // the chat ended
    }
}
```

- `onBotStart` is called for each bot packet that reports the conversation as created or running, so it can repeat with
  the same IDs. Handle it more than once.
- `onBotConversationFinished` is called when a chat ends, bot chat or live agent chat. It can be reported more than
  once for one conversation.
- The listener is always called on the main thread, so you can update your UI from it.

### iOS

The SDK posts three `NSNotification`s. They are posted by name, so no header is needed.

| Notification name | `userInfo` |
|---|---|
| `ReveChatBotStartNotification` | `botId`, `sessionId` |
| `ReveChatWebHookNotification` | `script` |
| `ReveChatBotFinishedNotification` | none |

```swift
NotificationCenter.default.addObserver(forName: Notification.Name("ReveChatBotStartNotification"),
                                       object: nil, queue: .main) { note in
    let botId = note.userInfo?["botId"] as? String
    let sessionId = note.userInfo?["sessionId"] as? String
}
NotificationCenter.default.addObserver(forName: Notification.Name("ReveChatWebHookNotification"),
                                       object: nil, queue: .main) { note in
    let script = note.userInfo?["script"] as? String ?? ""
}
NotificationCenter.default.addObserver(forName: Notification.Name("ReveChatBotFinishedNotification"),
                                       object: nil, queue: .main) { _ in
}
```

```objc
[[NSNotificationCenter defaultCenter] addObserverForName:@"ReveChatWebHookNotification" object:nil queue:NSOperationQueue.mainQueue
                                              usingBlock:^(NSNotification *note) {
    NSString *script = note.userInfo[@"script"];
}];
```

- Bot start is posted when the bot reports the conversation as created, and when it reports it as running with new IDs
  (the same IDs are not posted twice in a row).
- The webhook notification is posted for every script, whether or not the script can be read.
- Finished is posted once per conversation. It is armed again when a new bot conversation or a live chat starts.
- Observe with `queue: .main` as above. Some notifications can arrive on a background thread.

### React Native

```ts
import { addChatListener } from 'react-native-revechat';

const stopStart = addChatListener('botStart', ({ botId, sessionId }) => { /* ... */ });
const stopHook = addChatListener('webHook', ({ script }) => { /* ... */ });
const stopEnd = addChatListener('botFinished', () => { /* ... */ });

// later, for example when the screen unmounts
stopStart(); stopHook(); stopEnd();
```

- `addChatListener` returns a function that removes the listener.
- On Android the wrapper attaches its SDK listener as soon as JavaScript uses the module, so events are delivered even
  before the first `startChat`. If your app also registers its own native `REVEChatEventListener`, both receive every
  event with an SDK that has `addListener`; with an older SDK (one listener) the last one registered receives them.
- It needs an SDK build that has the events. An older SDK sends none.

---

## 3. Chat screen events (opened, closed, unread count)

For a badge on your own chat button and to know when the chat is on screen. The same three events exist on Android,
iOS and React Native.

| Event | When |
|---|---|
| Opened | The chat screen came to the front. The unread count is already 0 |
| Closed | The chat screen left the front: closed, or the app went to the background. A picker or camera shown over the chat does not count |
| Unread count | The number of messages from the agent or bot that arrived while the chat screen was not open changed |

The count is kept on the phone, so it survives the app being closed. Opening the chat resets it, and logout deletes it.
All events are delivered on the main thread.

### Android

```java
REVEChatEventManager.INSTANCE.addWindowListener(new REVEChatWindowListener() {
    @Override public void onChatOpened() { }
    @Override public void onChatClosed() { }
    @Override public void onUnreadCountChanged(int count) { badge.setCount(count); }
});
int unread = ReveChat.getUnreadCount();
```

### iOS

```swift
NotificationCenter.default.addObserver(forName: Notification.Name("ReveChatOpenedNotification"), object: nil, queue: .main) { _ in }
NotificationCenter.default.addObserver(forName: Notification.Name("ReveChatClosedNotification"), object: nil, queue: .main) { _ in }
NotificationCenter.default.addObserver(forName: Notification.Name("ReveChatUnreadCountNotification"), object: nil, queue: .main) { note in
    let count = note.userInfo?["count"] as? Int ?? 0
}
let unread = ReveChatManager.unreadMessageCount()
```

### React Native

```ts
import { addChatListener, getUnreadCount } from 'react-native-revechat';

const stopOpen = addChatListener('chatOpened', () => {});
const stopClose = addChatListener('chatClosed', () => {});
const stopCount = addChatListener('unreadCount', ({ count }) => setBadge(count));
const unread = await getUnreadCount();
```

Needs Android SDK 3.4.8 or later and an iOS SDK with `unreadMessageCount`; an older SDK sends no events and
`getUnreadCount()` resolves 0.

---

## 4. Telling the bot who the customer is

The SDK does not carry your login token. The web chat works like this, and the app follows the same steps:

1. Start the chat for the right bot with the widget ID: `ReveChat.setWidgetId(...)` on Android, the `widgetId`
   property on `ReveChatManager` on iOS, and the `widgetId` option of `startChat` in React Native.
2. The bot conversation starts. The app gets the bot start event with the bot ID and session ID.
3. The server sends the script. The app gets the webhook event with text like
   `functionName({"chatbot_id":"...","session_id":"..."});`.
4. Your app reads `chatbot_id` and `session_id` from the script and calls **your own login webhook** on your server,
   with the customer's login token and those two IDs. Your server tells ReveChat that this session belongs to that
   verified customer.
5. The bot continues knowing who the customer is.

Reading the IDs on Android:

```java
@Override public void onWebHookEvent(String scriptInfo) {
    try {
        int open = scriptInfo.indexOf('(');
        int close = scriptInfo.lastIndexOf(')');
        JSONObject args = new JSONObject(scriptInfo.substring(open + 1, close));
        String chatbotId = args.getString("chatbot_id");
        String sessionId = args.getString("session_id");
        // call your login webhook with the customer's token, chatbotId and sessionId
    } catch (Exception e) {
        // not a login script
    }
}
```

The customer's token never goes through the ReveChat SDK. The name and phone number passed in `setVisitorInfo` are
plain details, not proof of identity.

---

## 5. Notes

- **Event order** is: bot start, then the webhook script, and later finished.
- On iOS, observe with `queue: .main` as shown above. On Android the listener is already called on the main thread.
