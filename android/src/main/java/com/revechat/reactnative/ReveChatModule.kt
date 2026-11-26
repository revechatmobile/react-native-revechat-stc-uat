package com.revechat.reactnative

import android.content.Intent
import androidx.lifecycle.ProcessLifecycleOwner
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.revesoft.revechatsdk.message.processor.PushMessageProcessor
import com.revesoft.revechatsdk.model.VisitorInfo
import com.revesoft.revechatsdk.ui.activity.ReveChatActivity
import com.revesoft.revechatsdk.utils.REVEChatAppLifecycleObserver
import com.revesoft.revechatsdk.utils.ReveChat
import org.json.JSONObject

class ReveChatModule(context: ReactApplicationContext) : ReactContextBaseJavaModule(context) {

  override fun getName(): String = NAME

  // SDK 3.4.0 does not register this itself. Adding the same observer twice is a no-op, so this is
  // safe with newer SDK versions that register it at startup.
  override fun initialize() {
    UiThreadUtil.runOnUiThread {
      ProcessLifecycleOwner.get().lifecycle.addObserver(REVEChatAppLifecycleObserver.INSTANCE)
    }
    // The module exists as soon as JavaScript first uses it, which is before the first startChat: the bot events are
    // forwarded from here on, not only after startChat.
    registerEvents()
  }

  @ReactMethod
  fun startChat(options: ReadableMap, promise: Promise) {
    val accountId = options.optString("accountId")
    if (accountId.isBlank()) {
      promise.reject("E_INVALID_ARGUMENT", "accountId is required")
      return
    }
    try {
      ReveChat.init(accountId)
      // Empty means follow the device language. Called by name: the language option needs SDK 3.4.5 or later and the
      // font option 3.4.6 or later, and an older SDK must still build (it ignores the option).
      callSdk("setLanguage", arrayOf(String::class.java), options.optString("language"))
      // No font (or an empty one) puts the system font back.
      val font = if (options.hasKey("font") && !options.isNull("font")) options.getMap("font") else null
      callSdk(
        "setFont",
        arrayOf(android.content.Context::class.java, String::class.java, String::class.java, String::class.java),
        reactApplicationContext,
        font?.optString("regular"),
        font?.optString("medium"),
        font?.optString("bold"),
      )
      // Empty puts the account's default widget back. Needs an SDK with setWidgetId (an older one ignores it).
      callSdk("setWidgetId", arrayOf(String::class.java), options.optString("widgetId").trim().ifEmpty { null })
      applyBackground(options)
      registerEvents()
      ReveChat.setVisitorInfo(
        VisitorInfo.Builder()
          .name(options.optString("name"))
          .email(options.optString("email"))
          .phoneNumber(options.optString("phone"))
          .build()
      )
      val intent = Intent(reactApplicationContext, ReveChatActivity::class.java)
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      reactApplicationContext.startActivity(intent)
      promise.resolve(null)
    } catch (e: Exception) {
      promise.reject("E_START_CHAT", e.message, e)
    }
  }

  @ReactMethod
  fun setDeviceToken(token: String, promise: Promise) {
    if (token.isBlank()) {
      promise.reject("E_INVALID_ARGUMENT", "token is required")
      return
    }
    try {
      // Same call the native guide makes from FirebaseMessagingService.onNewToken. It also updates the
      // token on the server when a visitor already exists.
      PushMessageProcessor(reactApplicationContext).onNewToken(token)
      promise.resolve(null)
    } catch (e: Exception) {
      promise.reject("E_SET_DEVICE_TOKEN", e.message, e)
    }
  }

  @ReactMethod
  fun handlePushMessage(data: ReadableMap, promise: Promise) {
    try {
      // Same call the native guide makes from FirebaseMessagingService.onMessageReceived.
      PushMessageProcessor(reactApplicationContext).handlePushMessage(JSONObject(data.toHashMap()))
      promise.resolve(null)
    } catch (e: Exception) {
      promise.reject("E_PUSH_MESSAGE", e.message, e)
    }
  }

  @ReactMethod
  fun setLogEnabled(enabled: Boolean, promise: Promise) {
    ReveChat.setLogEnabled(enabled)
    promise.resolve(null)
  }

  @ReactMethod
  fun setServiceNotification(title: String, content: String, promise: Promise) {
    ReveChat.setApiServiceTitle(title)
    ReveChat.setApiServiceContent(content)
    promise.resolve(null)
  }

  /** Deletes the chat history and visitor identity stored for one account (SDK 3.4.6 or later). */
  @ReactMethod
  fun clearAccountData(accountId: String, promise: Promise) {
    if (accountId.isBlank()) {
      promise.reject("E_INVALID_ARGUMENT", "accountId is required")
      return
    }
    try {
      val method = ReveChat::class.java.getMethod("clearDataForAccount", String::class.java)
      method.invoke(null, accountId.trim())
      promise.resolve(null)
    } catch (e: NoSuchMethodException) {
      promise.reject("E_UNSUPPORTED", "This ReveChat SDK version cannot clear account data (needs 3.4.6 or later)", e)
    } catch (e: java.lang.reflect.InvocationTargetException) {
      promise.reject("E_CLEAR_DATA", e.targetException?.message ?: e.message, e.targetException ?: e)
    } catch (e: Exception) {
      promise.reject("E_CLEAR_DATA", e.message, e)
    }
  }

  /**
   * STC build only: chooses the chat server, "production" (default) or "uat". Needs the STC SDK that has
   * ReveChat.setEnvironment; other builds and older SDKs reject with E_UNSUPPORTED.
   */
  @ReactMethod
  fun setEnvironment(environment: String, promise: Promise) {
    val name = environment.trim().uppercase()
    if (name != "PRODUCTION" && name != "UAT") {
      promise.reject("E_INVALID_ARGUMENT", "environment must be 'production' or 'uat'")
      return
    }
    try {
      val enumClass = Class.forName("com.revesoft.revechatsdk.utils.ReveChatEnvironment")
      val value = enumClass.enumConstants!!.first { (it as Enum<*>).name == name }
      ReveChat::class.java.getMethod("setEnvironment", enumClass).invoke(null, value)
      promise.resolve(null)
    } catch (e: ClassNotFoundException) {
      promise.reject("E_UNSUPPORTED", "This ReveChat SDK has no environment switch (needs the STC SDK)", e)
    } catch (e: NoSuchMethodException) {
      promise.reject("E_UNSUPPORTED", "This ReveChat SDK has no environment switch (needs the STC SDK)", e)
    } catch (e: java.lang.reflect.InvocationTargetException) {
      promise.reject("E_ENVIRONMENT", e.targetException?.message ?: e.message, e.targetException ?: e)
    } catch (e: Exception) {
      promise.reject("E_ENVIRONMENT", e.message, e)
    }
  }

  /**
   * Logs the visitor out: closes the chat and clears the local chat history, visitor id and saved visitor details, so
   * the next chat starts as a new visitor (SDK 3.4.7 or later).
   */
  @ReactMethod
  fun logout(promise: Promise) {
    try {
      ReveChat::class.java.getMethod("logout").invoke(null)
      promise.resolve(null)
    } catch (e: NoSuchMethodException) {
      promise.reject("E_UNSUPPORTED", "This ReveChat SDK version has no logout (needs a newer Android SDK)", e)
    } catch (e: java.lang.reflect.InvocationTargetException) {
      promise.reject("E_LOGOUT", e.targetException?.message ?: e.message, e.targetException ?: e)
    } catch (e: Exception) {
      promise.reject("E_LOGOUT", e.message, e)
    }
  }

  /** Messages that arrived while the chat screen was not open (0 on an SDK without the counter). */
  @ReactMethod
  fun getUnreadCount(promise: Promise) {
    try {
      promise.resolve((ReveChat::class.java.getMethod("getUnreadCount").invoke(null) as? Int) ?: 0)
    } catch (e: Throwable) {
      promise.resolve(0)
    }
  }

  // --- events ---------------------------------------------------------------------------------------------------------

  private var eventsRegistered = false

  /** Forwards the SDK's bot events to JavaScript. Safe to call again, and a no-op on an SDK without the event API. */
  private fun registerEvents() {
    if (eventsRegistered) return
    try {
      registerEventListener()
      eventsRegistered = true
      registerWindowListener()
    } catch (e: Throwable) {
      // older SDK without com.revesoft.revechatsdk.event: the events simply never fire
    }
  }

  private fun registerEventListener() {
    val listener =
      object : com.revesoft.revechatsdk.event.REVEChatEventListener {
        override fun onBotStart(botId: String, sessionId: String) {
          emit("ReveChatBotStart", Arguments.createMap().apply {
            putString("botId", botId)
            putString("sessionId", sessionId)
          })
        }

        override fun onWebHookEvent(scriptInfo: String?) {
          emit("ReveChatWebHook", Arguments.createMap().apply { putString("script", scriptInfo ?: "") })
        }

        override fun onBotConversationFinished() {
          emit("ReveChatBotFinished", Arguments.createMap())
        }
      }
    val manager = com.revesoft.revechatsdk.event.REVEChatEventManager
    try {
      // Newer SDKs allow more than one listener, so this does not replace the host app's own listener.
      manager.javaClass
        .getMethod("addListener", com.revesoft.revechatsdk.event.REVEChatEventListener::class.java)
        .invoke(manager, listener)
    } catch (e: NoSuchMethodException) {
      // Older SDK: it keeps a single listener, so this one is it (a listener the host app registers replaces it).
      manager.registerListener(listener)
    }
  }

  /** Chat screen opened / closed and the unread count. Only SDK 3.4.8 or later has these; on an older SDK they never fire. */
  private fun registerWindowListener() {
    try {
      val listenerClass = Class.forName("com.revesoft.revechatsdk.event.REVEChatWindowListener")
      val listener = java.lang.reflect.Proxy.newProxyInstance(listenerClass.classLoader, arrayOf(listenerClass)) { _, method, args ->
        when (method.name) {
          "onChatOpened" -> emit("ReveChatOpened", Arguments.createMap())
          "onChatClosed" -> emit("ReveChatClosed", Arguments.createMap())
          "onUnreadCountChanged" ->
            emit("ReveChatUnreadCount", Arguments.createMap().apply { putInt("count", (args?.getOrNull(0) as? Int) ?: 0) })
        }
        null
      }
      val manager = com.revesoft.revechatsdk.event.REVEChatEventManager
      manager.javaClass.getMethod("addWindowListener", listenerClass).invoke(manager, listener)
    } catch (e: Throwable) {
      // older SDK without the window events: they simply never fire
    }
  }

  private fun emit(name: String, payload: com.facebook.react.bridge.WritableMap) {
    try {
      if (reactApplicationContext.hasActiveReactInstance()) {
        reactApplicationContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java).emit(name, payload)
      }
    } catch (e: Exception) {
      // JavaScript is not running (app in the background): the event is dropped
    }
  }

  // Required by NativeEventEmitter on the JavaScript side. Also makes sure the SDK events are being forwarded.
  @ReactMethod
  fun addListener(eventName: String) {
    registerEvents()
  }

  @ReactMethod
  fun removeListeners(count: Int) {}

  /** Background option: an exact colour wins, otherwise the theme; empty or 'light' is the SDK's own look. */
  private fun applyBackground(options: ReadableMap) {
    val color = options.optString("backgroundColor").trim()
    if (color.isNotEmpty()) {
      val parsed = try { android.graphics.Color.parseColor(if (color.startsWith("#")) color else "#$color") } catch (e: IllegalArgumentException) { null }
      if (parsed != null) {
        callSdk("setBackgroundColor", arrayOf(Int::class.javaPrimitiveType!!), parsed)
        return
      }
    }
    callSdk("resetBackground", arrayOf())
    val theme = options.optString("backgroundTheme").lowercase()
    if (theme == "dark" || theme == "system") {
      try {
        val mode = Class.forName("com.revesoft.revechatsdk.utils.background.ReveChatBackground\$Mode")
        @Suppress("UNCHECKED_CAST")
        val value = java.lang.Enum.valueOf(mode as Class<out Enum<*>>, theme.uppercase())
        callSdk("setBackgroundTheme", arrayOf(mode), value)
      } catch (e: ClassNotFoundException) {
        // older SDK: the option is not available
      }
    }
  }

  /** Calls an SDK method that only newer SDK versions have; an older SDK just ignores the option. */
  private fun callSdk(name: String, parameterTypes: Array<Class<*>>, vararg args: Any?) {
    try {
      ReveChat::class.java.getMethod(name, *parameterTypes).invoke(null, *args)
    } catch (e: NoSuchMethodException) {
      // older SDK: the option is not available
    } catch (e: java.lang.reflect.InvocationTargetException) {
      throw (e.targetException as? Exception) ?: e // the SDK's own error, not the reflection wrapper
    }
  }

  private fun ReadableMap.optString(key: String): String =
    if (hasKey(key) && !isNull(key)) getString(key) ?: "" else ""

  companion object {
    const val NAME = "ReveChat"
  }
}
