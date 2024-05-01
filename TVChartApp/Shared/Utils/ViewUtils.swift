import Foundation
import SwiftUI

extension View {
  
  /// Runs a `Task` executing the given closure; trap errors and add them to the provided list
  /// for display in the UI.
  func runTaskWithErrorReporting(using errorDisplayList: ErrorDisplayList, task: @escaping () async throws -> Void) {
    Task {
      do {
        try await task()
      } catch {
        await MainActor.run {
          withAnimation {
            errorDisplayList.add(error)
          }
        }
      }
    }
  }
}

