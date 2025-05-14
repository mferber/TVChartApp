import SwiftUI

// For Paul Hudson's shake-to-undo implementation
// https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-shake-gestures
extension UIWindow {
  open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    if motion == .motionShake {
      NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
    }
  }
}
