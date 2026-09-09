import Flutter
import UIKit
import AppTrackingTransparency
import Airbridge
import airbridge_flutter_sdk

class SceneDelegate: FlutterSceneDelegate {
  private var hasStartedAirbridgeTracking = false
  private var hasScheduledTrackingAuthorizationRequest = false

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    if isTrackingAuthorized {
      startAirbridgeTrackingIfNeeded()
      if hasStartedAirbridgeTracking {
        AirbridgeFlutter.trackDeeplink(connectionOptions: connectionOptions)
      }
    }
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)

    guard #available(iOS 14, *) else {
      startAirbridgeTrackingIfNeeded()
      return
    }

    switch ATTrackingManager.trackingAuthorizationStatus {
    case .authorized:
      startAirbridgeTrackingIfNeeded()
    case .notDetermined:
      requestTrackingAuthorizationWhenReady()
    case .denied, .restricted:
      print("[LuckyGamesAirbridge] Tracking is disabled because ATT permission was not granted.")
    @unknown default:
      print("[LuckyGamesAirbridge] Tracking is disabled because the ATT status is unknown.")
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    if isTrackingAuthorized {
      startAirbridgeTrackingIfNeeded()
      if hasStartedAirbridgeTracking {
        AirbridgeFlutter.trackDeeplink(openURLContexts: URLContexts)
      }
    }
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    super.scene(scene, continue: userActivity)
    if isTrackingAuthorized {
      startAirbridgeTrackingIfNeeded()
      if hasStartedAirbridgeTracking {
        AirbridgeFlutter.trackDeeplink(userActivity: userActivity)
      }
    }
  }

  private var isTrackingAuthorized: Bool {
    if #available(iOS 14, *) {
      return ATTrackingManager.trackingAuthorizationStatus == .authorized
    }
    return true
  }

  private func requestTrackingAuthorizationWhenReady() {
    guard !hasScheduledTrackingAuthorizationRequest else { return }
    hasScheduledTrackingAuthorizationRequest = true

    // Let the Flutter first frame become visible before presenting the system
    // prompt. Presenting during the initial scene transition can be ignored.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      guard let self = self else { return }
      self.hasScheduledTrackingAuthorizationRequest = false

      guard
        UIApplication.shared.applicationState == .active,
        ATTrackingManager.trackingAuthorizationStatus == .notDetermined
      else { return }

      ATTrackingManager.requestTrackingAuthorization { [weak self] status in
        DispatchQueue.main.async {
          print("[LuckyGamesAirbridge] ATT status: \(status.rawValue)")
          if status == .authorized {
            self?.startAirbridgeTrackingIfNeeded()
          } else {
            print("[LuckyGamesAirbridge] Tracking remains disabled because ATT permission was not granted.")
          }
        }
      }
    }
  }

  private func startAirbridgeTrackingIfNeeded() {
    guard !hasStartedAirbridgeTracking, isTrackingAuthorized else { return }

    guard
      let appDelegate = UIApplication.shared.delegate as? AppDelegate,
      appDelegate.initializeAirbridgeIfNeeded()
    else { return }

    hasStartedAirbridgeTracking = true
    Airbridge.startTracking()
    print("[LuckyGamesAirbridge] Tracking started after permission was granted.")
  }
}
