import SwiftUI

// For Paul Hudson's shake-to-undo implementation
// https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-shake-gestures
extension UIDevice {
  static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}
