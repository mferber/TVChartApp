import SwiftUI

// Each toast needs a distinct ID to distinguish between toasts with
// the same text
struct ToastItem {
  var message: String
  var id: UUID
}

// Displays a sequence of "toast" messages as centered text overlays.
// View is bound to a queue (array) of pending ToastItem descriptors.
// Each toast will be displayed sequentially until the queue is empty.
struct Toast: View {
  @Binding var pendingToasts: [ToastItem]

  private static let messageDuration = 1.0

  var body: some View {
    if let msg = pendingToasts.first {
      ToastText(message: msg.message)
        .task {
          await removeAfterDelay()
        }
        .id(msg.id) // prevent sequential toasts from being treated as same view
    }
  }

  private func removeAfterDelay() async {
    do {
      try await Task.sleep(for: .seconds(Self.messageDuration))
    } catch {
      // don't care if task was cancelled
    }
    _ = pendingToasts.removeFirst()
  }
}

private struct ToastText: View {
  let message: String

  @ScaledMetric private var horizPadding = 15.0
  @ScaledMetric private var vertPadding = 10.0
  @ScaledMetric private var cornerRadius = 20.0

  private static let opacity = 0.95
  private static let transitionDuration = 0.3

  var body: some View {
    Text(message)
      .multilineTextAlignment(.center)
      .fontWeight(.bold)
      .foregroundStyle(.white)
      .padding(.horizontal, horizPadding)
      .padding(.vertical, vertPadding)
      .background(.toast.opacity(Self.opacity))
      .cornerRadius(cornerRadius)
      .padding()
      .frame(alignment: .center)
      .transition(
        .opacity.animation(.easeInOut(duration: Self.transitionDuration))
      )
  }
}

#Preview {
  ToastText(message: "hello world")
}
