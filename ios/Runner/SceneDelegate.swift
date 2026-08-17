import Flutter
import UIKit
import AppTrackingTransparency
import airbridge_flutter_sdk

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    AirbridgeFlutter.trackDeeplink(connectionOptions: connectionOptions)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)

    if #available(iOS 14, *),
       ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
      ATTrackingManager.requestTrackingAuthorization { status in
        print("[LuckyGamesAirbridge] ATT status: \(status.rawValue)")
      }
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    AirbridgeFlutter.trackDeeplink(openURLContexts: URLContexts)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    super.scene(scene, continue: userActivity)
    AirbridgeFlutter.trackDeeplink(userActivity: userActivity)
  }
}
