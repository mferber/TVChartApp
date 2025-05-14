import SwiftUI

// For Paul Hudson's shake-to-undo implementation
// https://www.hackingwithswift.com/quick-start/swiftui/how-to-detect-shake-gestures
struct DeviceShakeViewModifier: ViewModifier {
  let action: () -> Void

  func body(content: Content) -> some View {
    content
      .onAppear()
      .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
        action()
      }
  }
}

extension View {
  func onShake(perform action: @escaping () -> Void) -> some View {
    self.modifier(DeviceShakeViewModifier(action: action))
  }
}

