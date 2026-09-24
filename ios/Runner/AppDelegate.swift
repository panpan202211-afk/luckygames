import Flutter
import UIKit
import airbridge_flutter_sdk
import WebKit
import webview_flutter_wkwebview

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var webViewChannel: FlutterMethodChannel?
  private var airbridgeReady = false
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    initializeAirbridge()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func initializeAirbridge() {
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
      return
    }

    AirbridgeFlutter.initializeSDK(name: appName, token: appToken)
    airbridgeReady = (config["sdkEnabled"] as? Bool) != false
    print("[LuckyGamesAirbridge] SDK initialized for \(appName).")
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
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LuckyGamesWebViewBridge") else {
      return
    }
    let channel = FlutterMethodChannel(name: "lucky_games/webview", binaryMessenger: registrar.messenger())
    webViewChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "isAirbridgeReady" {
        result(self?.airbridgeReady ?? false)
        return
      }
      if call.method == "installTrackingScript" {
        guard let args = call.arguments as? [String: Any],
              let identifier = args["identifier"] as? NSNumber,
              let script = args["script"] as? String,
              let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
                forIdentifier: identifier.int64Value, withPluginRegistrar: registrar)
        else {
          result(FlutterError(code: "webview_missing", message: "Tracking WebView is unavailable.", details: nil))
          return
        }
        webView.configuration.userContentController.addUserScript(WKUserScript(
          source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        result(true)
        return
      }
      guard call.method == "openExternal" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let rawURL = args["url"] as? String,
            let url = URL(string: rawURL),
            let scheme = url.scheme?.lowercased(),
            !["http", "https", "file", "content", "javascript", "data", "blob", "about", "intent"].contains(scheme)
      else {
        result(["opened": false])
        return
      }
      // Direct open does not require LSApplicationQueriesSchemes or a permission
      // prompt. WKWebView retains its native photo/file input picker.
      UIApplication.shared.open(url, options: [:]) { opened in
        result(["opened": opened])
      }
    }
  }
}
