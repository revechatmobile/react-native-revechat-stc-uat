require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

# 3.1.0-stc-uat is the STC build of ReveChatSDK 3.1.0 (production by default, UAT via setEnvironment; the zip behind it
# was replaced on 26 Nov 2026, so older installs need `pod cache clean ReveChatSDK --all`): an XCFramework (device + simulator) whose only
# dependency is WebRTC-lib, so the host Podfile needs no ReveChat hooks. It is a CocoaPods pre-release, which
# only resolves when named exactly ("~> 3.1" will not pick it). Move to "~> 3.1" once 3.1.0 is published.
# Override per app with REVECHAT_IOS_SDK_VERSION.
sdk_version = ENV["REVECHAT_IOS_SDK_VERSION"] || "3.1.0-stc-uat"

Pod::Spec.new do |s|
  s.name         = "react-native-revechat"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "15.0" }
  s.source       = { :git => package["repository"]["url"], :tag => "v#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm}"

  s.dependency "ReveChatSDK", sdk_version

  if respond_to?(:install_modules_dependencies, true)
    install_modules_dependencies(s)
  else
    s.dependency "React-Core"
  end
end
