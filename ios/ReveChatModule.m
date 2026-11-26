#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/message.h>
#import <ReveChatSDK/ReveChatSDK.h>

@interface ReveChatModule : RCTEventEmitter <RCTBridgeModule>
@end

@implementation ReveChatModule

RCT_EXPORT_MODULE(ReveChat)

// Posted by the SDK (names are plain strings, so an older SDK that never posts them still links).
static NSString *const ReveChatBotStartNotification = @"ReveChatBotStartNotification";
static NSString *const ReveChatWebHookNotification = @"ReveChatWebHookNotification";
static NSString *const ReveChatBotFinishedNotification = @"ReveChatBotFinishedNotification";
static NSString *const ReveChatOpenedNotification = @"ReveChatOpenedNotification";
static NSString *const ReveChatClosedNotification = @"ReveChatClosedNotification";
static NSString *const ReveChatUnreadCountNotification = @"ReveChatUnreadCountNotification";

// Posted by the host app from userNotificationCenter(_:didReceive:withCompletionHandler:), with the
// UNNotificationResponse as the object. The app owns the notification delegate (an app has only one), so the wrapper
// cannot receive taps by itself.
static NSString *const ReveChatNotificationTappedNotification = @"ReveChatNotificationTapped";

// The latest tap that no notificationTap listener has taken yet. Handed over once by getPendingNotificationTap.
static NSDictionary *sPendingNotificationTap = nil;
// The module while JS has listeners (of any event), so it can be told that a tap is waiting.
static __weak ReveChatModule *sObservingModule = nil;

// What the tap was on. The SDK's local notifications carry no userInfo, so their identifier is all there is; a remote
// (APNs) push has no ReveChat identifier and the app decides from its payload.
static NSString *ReveChatNotificationKind(UNNotificationRequest *request)
{
  if ([request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
    return @"remote";
  }
  NSString *identifier = request.identifier;
  if ([identifier hasPrefix:@"ReveChatLanding_"] || [identifier hasPrefix:@"ReveChatAgent_"]) {
    return @"message";
  }
  if ([identifier isEqualToString:@"OutsideNotification"]) {
    return @"chatStarted";
  }
  if ([identifier hasPrefix:@"ReveChatIncomingCall_"]) {
    return @"call";
  }
  return @"other";
}

static NSDictionary *ReveChatNotificationTapBody(UNNotificationResponse *response)
{
  UNNotificationRequest *request = response.notification.request;
  // userInfo may hold any property-list type (dates, data) that cannot cross to JS; send it only when it is plain JSON.
  NSDictionary *userInfo = request.content.userInfo;
  NSDictionary *data = [NSJSONSerialization isValidJSONObject:userInfo] ? userInfo : @{};
  return @{
    @"kind" : ReveChatNotificationKind(request),
    @"identifier" : request.identifier ?: @"",
    @"data" : data,
  };
}

// Registered at load time, before the app finishes launching, so the tap that launches the app is not missed even
// though React Native creates this module later. A constructor function, because RCT_EXPORT_MODULE already defines
// +load.
__attribute__((constructor)) static void ReveChatObserveNotificationTaps(void)
{
  [NSNotificationCenter.defaultCenter addObserverForName:ReveChatNotificationTappedNotification
                                                  object:nil
                                                   queue:NSOperationQueue.mainQueue
                                              usingBlock:^(NSNotification *note) {
    if (![note.object isKindOfClass:[UNNotificationResponse class]]) {
      return;
    }
    UNNotificationResponse *response = note.object;
    // Swiping a notification away is not a tap (iOS reports it only for categories that ask for it).
    if ([response.actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier]) {
      return;
    }
    // Always kept: "JS has listeners" does not mean one of them listens for taps (it may only have chat or bot
    // listeners). The event only says that a tap is waiting; a notificationTap listener takes it.
    sPendingNotificationTap = ReveChatNotificationTapBody(response);
    [sObservingModule sendEventWithName:@"ReveChatNotificationTap" body:@{}];
  }];
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[ @"ReveChatBotStart", @"ReveChatWebHook", @"ReveChatBotFinished", @"ReveChatOpened", @"ReveChatClosed",
            @"ReveChatUnreadCount", @"ReveChatNotificationTap" ];
}

- (void)startObserving
{
  NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
  [center addObserver:self selector:@selector(onBotStart:) name:ReveChatBotStartNotification object:nil];
  [center addObserver:self selector:@selector(onWebHook:) name:ReveChatWebHookNotification object:nil];
  [center addObserver:self selector:@selector(onBotFinished:) name:ReveChatBotFinishedNotification object:nil];
  sObservingModule = self;
  [center addObserver:self selector:@selector(onChatOpened:) name:ReveChatOpenedNotification object:nil];
  [center addObserver:self selector:@selector(onChatClosed:) name:ReveChatClosedNotification object:nil];
  [center addObserver:self selector:@selector(onUnreadCount:) name:ReveChatUnreadCountNotification object:nil];
}

- (void)stopObserving
{
  [NSNotificationCenter.defaultCenter removeObserver:self];
  if (sObservingModule == self) {
    sObservingModule = nil;
  }
}

// The waiting tap, or null. Returned once.
RCT_EXPORT_METHOD(getPendingNotificationTap:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSDictionary *tap = sPendingNotificationTap;
  sPendingNotificationTap = nil;
  resolve(tap ?: (id)[NSNull null]);
}

- (void)onBotStart:(NSNotification *)note
{
  [self sendEventWithName:@"ReveChatBotStart"
                     body:@{ @"botId" : note.userInfo[@"botId"] ?: @"", @"sessionId" : note.userInfo[@"sessionId"] ?: @"" }];
}

- (void)onWebHook:(NSNotification *)note
{
  [self sendEventWithName:@"ReveChatWebHook" body:@{ @"script" : note.userInfo[@"script"] ?: @"" }];
}

- (void)onBotFinished:(NSNotification *)note
{
  [self sendEventWithName:@"ReveChatBotFinished" body:@{}];
}

- (void)onChatOpened:(NSNotification *)note
{
  [self sendEventWithName:@"ReveChatOpened" body:@{}];
}

- (void)onChatClosed:(NSNotification *)note
{
  [self sendEventWithName:@"ReveChatClosed" body:@{}];
}

- (void)onUnreadCount:(NSNotification *)note
{
  [self sendEventWithName:@"ReveChatUnreadCount" body:@{ @"count" : note.userInfo[@"count"] ?: @0 }];
}

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

// The SDK presents UIKit screens, and React Native would otherwise call these on its own queue.
- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

static NSString *ReveChatString(NSDictionary *options, NSString *key)
{
  id value = options[key];
  return [value isKindOfClass:[NSString class]] ? value : @"";
}

static UIViewController *ReveChatTopViewController(void)
{
  UIWindowScene *scene = nil;
  for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
    if (![candidate isKindOfClass:[UIWindowScene class]]) {
      continue;
    }
    if (candidate.activationState == UISceneActivationStateForegroundActive) {
      scene = (UIWindowScene *)candidate;
      break;
    }
    if (scene == nil) {
      scene = (UIWindowScene *)candidate;
    }
  }

  UIWindow *window = nil;
  for (UIWindow *candidate in scene.windows) {
    if (candidate.isKeyWindow) {
      window = candidate;
      break;
    }
  }
  UIViewController *top = (window ?: scene.windows.firstObject).rootViewController;
  while (top.presentedViewController != nil) {
    top = top.presentedViewController;
  }
  return top;
}

// Finds a font file in the app bundle ("fonts/Cairo-Bold.ttf", "Cairo-Bold.ttf" or "Cairo-Bold"), registers it with
// the SDK and returns its PostScript name, or nil when it cannot be found or loaded.
static NSString *ReveChatRegisterFont(NSString *name)
{
  if (name.length == 0) {
    return nil;
  }
  NSString *file = name.lastPathComponent;
  NSString *base = file.stringByDeletingPathExtension;
  NSString *path = nil;
  for (NSString *ext in @[ file.pathExtension.length ? file.pathExtension : @"ttf", @"otf", @"ttf" ]) {
    path = [NSBundle.mainBundle pathForResource:base ofType:ext];
    if (path == nil) {
      path = [NSBundle.mainBundle pathForResource:base ofType:ext inDirectory:@"fonts"];
    }
    if (path != nil) {
      break;
    }
  }
  if (path == nil) {
    NSLog(@"react-native-revechat: font file not found in the app bundle: %@", name);
    return nil;
  }
  // ReveChatFont exists from the SDK version with font support; older pods do not have it, so no direct link.
  Class fontClass = NSClassFromString(@"ReveChatFont");
  if (fontClass == nil) {
    return nil;
  }
  NSError *error = nil;
  BOOL registered = ((BOOL (*)(Class, SEL, NSString *, NSError **))objc_msgSend)(
      fontClass, NSSelectorFromString(@"registerFontFileAtPath:error:"), path, &error);
  if (!registered) {
    NSLog(@"react-native-revechat: cannot register font %@: %@", name, error.localizedDescription);
    return nil;
  }
  CGDataProviderRef provider = CGDataProviderCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path]);
  if (provider == NULL) {
    return nil;
  }
  CGFontRef font = CGFontCreateWithDataProvider(provider);
  CGDataProviderRelease(provider);
  if (font == NULL) {
    return nil;
  }
  NSString *postScriptName = (__bridge_transfer NSString *)CGFontCopyPostScriptName(font);
  CGFontRelease(font);
  return postScriptName;
}

static void ReveChatApplyFont(NSDictionary *options)
{
  id font = options[@"font"];
  NSDictionary *files = [font isKindOfClass:[NSDictionary class]] ? font : @{};
  NSString *regular = ReveChatRegisterFont(ReveChatString(files, @"regular"));
  NSString *medium = ReveChatRegisterFont(ReveChatString(files, @"medium"));
  NSString *bold = ReveChatRegisterFont(ReveChatString(files, @"bold"));
  // All nil puts the system font back.
  Class fontClass = NSClassFromString(@"ReveChatFont");
  if (fontClass != nil) {
    ((void (*)(Class, SEL, NSString *, NSString *, NSString *))objc_msgSend)(
        fontClass, NSSelectorFromString(@"setRegular:medium:bold:"), regular, medium, bold);
  }
}

// Background option: an exact colour (hex string) wins, otherwise the theme. ReveChatBackground exists from the SDK
// version with background support; older pods do not have it, so no direct link.
static void ReveChatApplyBackground(NSDictionary *options)
{
  Class bg = NSClassFromString(@"ReveChatBackground");
  if (bg == nil) {
    return;
  }
  NSString *hex = ReveChatString(options, @"backgroundColor");
  // Nothing asked for (or plain 'light' with no colour) and nothing applied before: leave the SDK exactly as it is.
  // Only touch the SDK again when the choice changed, so a host that never uses the option is never affected.
  static NSString *applied = nil;
  NSString *themeName = [ReveChatString(options, @"backgroundTheme") lowercaseString];
  NSString *key = [NSString stringWithFormat:@"%@|%@", themeName.length ? themeName : @"light", hex];
  if (applied == nil && hex.length == 0 && (themeName.length == 0 || [themeName isEqualToString:@"light"])) {
    return;
  }
  if ([key isEqualToString:applied]) {
    return;
  }
  applied = key;
  if (hex.length > 0) {
    SEL hexSel = NSSelectorFromString(@"setBackgroundColorHex:");
    if ([bg respondsToSelector:hexSel]) {
      BOOL ok = ((BOOL (*)(Class, SEL, NSString *))objc_msgSend)(bg, hexSel, hex);
      if (ok) {
        return;
      }
    }
  }
  ((void (*)(Class, SEL, id))objc_msgSend)(bg, NSSelectorFromString(@"setBackgroundColor:"), nil);
  NSString *theme = [ReveChatString(options, @"backgroundTheme") lowercaseString];
  NSInteger value = [theme isEqualToString:@"dark"] ? 1 : ([theme isEqualToString:@"system"] ? 2 : 0);
  ((void (*)(Class, SEL, NSInteger))objc_msgSend)(bg, NSSelectorFromString(@"setBackgroundTheme:"), value);
}

RCT_EXPORT_METHOD(startChat:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSString *accountId = ReveChatString(options, @"accountId");
  if (accountId.length == 0) {
    reject(@"E_INVALID_ARGUMENT", @"accountId is required", nil);
    return;
  }

  UIViewController *presenter = ReveChatTopViewController();
  if (presenter == nil) {
    reject(@"E_NO_PRESENTER", @"No view controller to present the chat from", nil);
    return;
  }

  ReveChatManager *manager = [ReveChatManager sharedManager];
  ReveChatApplyFont(options);
  ReveChatApplyBackground(options);

  // The SDK presents its own navigation controller. If it is already on screen (for example after a
  // double tap), a second call would stack another chat on top of it.
  if (manager.myRootController != nil && manager.myRootController.presentingViewController != nil) {
    resolve(nil);
    return;
  }

  [manager setupAccountWith:accountId];
  // Remembered so logout can clear this account even after the app was restarted.
  [[NSUserDefaults standardUserDefaults] setObject:accountId forKey:@"ReveChatRNAccountId"];
  // Optional widget ID; empty uses the account's default widget. An SDK without widget ID support ignores it.
  if ([manager respondsToSelector:NSSelectorFromString(@"setWidgetId:")]) {
    NSString *widgetId = [ReveChatString(options, @"widgetId") stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [manager setValue:(widgetId.length > 0 ? widgetId : nil) forKey:@"widgetId"];
  }
  // Optional language override ("ar", "en", ...); empty follows the device language. Older SDK versions without
  // the `language` property ignore it.
  if ([manager respondsToSelector:@selector(setLanguage:)]) {
    NSString *language = ReveChatString(options, @"language");
    [manager setValue:(language.length > 0 ? language : nil) forKey:@"language"];
  }
  [manager initiateReveChatWith:ReveChatString(options, @"name")
                   visitorEmail:ReveChatString(options, @"email")
                  visitorMobile:ReveChatString(options, @"phone")
               onViewController:presenter];
  resolve(nil);
}

// Deletes what the SDK stored for one account. +[ReveChatManager clearDataForAccount:] exists only in newer iOS SDKs,
// so it is looked up by name.
RCT_EXPORT_METHOD(clearAccountData:(NSString *)accountId
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  if (accountId.length == 0) {
    reject(@"E_INVALID_ARGUMENT", @"accountId is required", nil);
    return;
  }
  Class managerClass = NSClassFromString(@"ReveChatManager");
  SEL selector = NSSelectorFromString(@"clearDataForAccount:");
  if (managerClass == nil || ![managerClass respondsToSelector:selector]) {
    reject(@"E_UNSUPPORTED", @"This ReveChat SDK version cannot clear account data", nil);
    return;
  }
  ((void (*)(Class, SEL, NSString *))objc_msgSend)(managerClass, selector, accountId);
  resolve(nil);
}

// STC iOS SDK only: chooses the chat server. +[ReveChatManager setEnvironment:] (0 = production, 1 = UAT) is looked up by
// name because other SDK builds do not have it.
RCT_EXPORT_METHOD(setEnvironment:(NSString *)environment
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  NSString *name = [environment lowercaseString];
  if (![name isEqualToString:@"production"] && ![name isEqualToString:@"uat"]) {
    reject(@"E_INVALID_ARGUMENT", @"environment must be 'production' or 'uat'", nil);
    return;
  }
  Class managerClass = NSClassFromString(@"ReveChatManager");
  SEL selector = NSSelectorFromString(@"setEnvironment:");
  if (managerClass == nil || ![managerClass respondsToSelector:selector]) {
    reject(@"E_UNSUPPORTED", @"This ReveChat SDK has no environment switch (needs the STC SDK)", nil);
    return;
  }
  ((void (*)(Class, SEL, NSInteger))objc_msgSend)(managerClass, selector, [name isEqualToString:@"uat"] ? 1 : 0);
  resolve(nil);
}

// Logs the visitor out: clears the data of the account the chat last ran on (history, visitor id, saved details) and
// stops its session, so the next chat starts as a new visitor.
RCT_EXPORT_METHOD(logout:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  Class managerClass = NSClassFromString(@"ReveChatManager");
  // Newer iOS SDKs have +logout, which clears the account in use.
  SEL logoutSelector = NSSelectorFromString(@"logout");
  if (managerClass != nil && [managerClass respondsToSelector:logoutSelector]) {
    ((void (*)(Class, SEL))objc_msgSend)(managerClass, logoutSelector);
    resolve(nil);
    return;
  }
  // Older SDKs: clear the account this app last started a chat on.
  NSString *accountId = [[NSUserDefaults standardUserDefaults] stringForKey:@"ReveChatRNAccountId"];
  if (accountId.length == 0) {
    resolve(nil); // no chat was ever started from this app: nothing stored
    return;
  }
  SEL selector = NSSelectorFromString(@"clearDataForAccount:");
  if (managerClass == nil || ![managerClass respondsToSelector:selector]) {
    reject(@"E_UNSUPPORTED", @"This ReveChat SDK version cannot log out", nil);
    return;
  }
  ((void (*)(Class, SEL, NSString *))objc_msgSend)(managerClass, selector, accountId);
  resolve(nil);
}

// Messages that arrived while the chat screen was not open (0 on an SDK without the counter).
RCT_EXPORT_METHOD(getUnreadCount:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  Class managerClass = NSClassFromString(@"ReveChatManager");
  SEL selector = NSSelectorFromString(@"unreadMessageCount");
  if (managerClass != nil && [managerClass respondsToSelector:selector]) {
    NSInteger count = ((NSInteger (*)(Class, SEL))objc_msgSend)(managerClass, selector);
    resolve(@(count));
    return;
  }
  resolve(@0);
}

RCT_EXPORT_METHOD(setDeviceToken:(NSString *)token
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  if (token.length == 0) {
    reject(@"E_INVALID_ARGUMENT", @"token is required", nil);
    return;
  }
  // APNSToken is what the SDK sends to the server as the push token. Not setDeviceToken:, which sets the
  // access token used for token verification. Expects the hex string form of the APNs device token.
  [ReveChatManager sharedManager].APNSToken = token;
  resolve(nil);
}

@end
