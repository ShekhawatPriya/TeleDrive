import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// The transfer Live Activity links to `teledrive://transfers`; everything
  /// else keeps Flutter's default handling.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let transfers = URLContexts.filter { TransferLiveActivityBridge.handles($0.url) }
    if !transfers.isEmpty {
      (UIApplication.shared.delegate as? AppDelegate)?.transferLiveActivity?.openTransfers()
    }
    let remaining = URLContexts.subtracting(transfers)
    if !remaining.isEmpty { super.scene(scene, openURLContexts: remaining) }
  }
}
