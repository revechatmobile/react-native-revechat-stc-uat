import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

// Apps built with the iOS 27 SDK must use the UIScene life cycle or they fail to launch on device
// ("UIScene life cycle is required for apps built with this SDK", Apple TN3187). Info.plist's
// UIApplicationSceneManifest names this class, and React Native starts here instead of in the app delegate.
class SceneDelegate: RCTDefaultReactNativeFactoryDelegate, UIWindowSceneDelegate {
  var window: UIWindow?
  var reactNativeFactory: RCTReactNativeFactory?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else {
      return
    }

    dependencyProvider = RCTAppDependencyProvider()
    let factory = RCTReactNativeFactory(delegate: self)
    reactNativeFactory = factory
    window = UIWindow(windowScene: windowScene)

    // React Native 0.86 has no scene-aware start (connectionOptions arrived in 0.88); a window created from the
    // window scene is enough.
    factory.startReactNative(withModuleName: "ReveChatExample", in: window)
  }

  override func sourceURL(for bridge: RCTBridge) -> URL? {
    bundleURL()
  }

  override func bundleURL() -> URL? {
#if DEBUG
    RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
#else
    Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }
}
