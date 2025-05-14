import SwiftUI

// MARK: - Task with error handling

/// Runs a `Task` executing the given closure; trap errors and add them to the provided list
/// for display in the UI.
func startTask(sendingErrorsTo errorDisplayList: ErrorDisplayList, task: @escaping () async throws -> Void) {
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
