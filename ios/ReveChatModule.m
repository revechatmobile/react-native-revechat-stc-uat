#import <React/RCTBridgeModule.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <ReveChatSDK/ReveChatSDK.h>

@interface ReveChatModule : NSObject <RCTBridgeModule>
@end

@implementation ReveChatModule

RCT_EXPORT_MODULE(ReveChat)

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
