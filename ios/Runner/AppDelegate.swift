import Flutter
import UIKit
import airbridge_flutter_sdk

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var hasInitializedAirbridge = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @discardableResult
  func initializeAirbridgeIfNeeded() -> Bool {
    if hasInitializedAirbridge {
      return true
    }

    guard
      let url = airbridgeConfigURL(),
      let data = try? Data(contentsOf: url),
      let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let appName = config["appName"] as? String,
      let appToken = config["appToken"] as? String,
      !appName.isEmpty,
      !appToken.isEmpty,
      !appName.hasPrefix("YOUR_"),
      !appToken.hasPrefix("YOUR_")
    else {
      print("[LuckyGamesAirbridge] Credentials are not configured; attribution is disabled.")
      return false
    }

    AirbridgeFlutter.initializeSDK(name: appName, token: appToken)
    hasInitializedAirbridge = true
    print("[LuckyGamesAirbridge] SDK initialized for \(appName).")
    return true
  }

  private func airbridgeConfigURL() -> URL? {
    if let bundledURL = Bundle.main.url(forResource: "airbridge", withExtension: "json") {
      return bundledURL
    }

    return Bundle.main.url(
      forResource: "airbridge",
      withExtension: "json",
      subdirectory: "Frameworks/App.framework/flutter_assets"
    )
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
