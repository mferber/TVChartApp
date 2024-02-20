import SwiftUI
import Combine

@main
struct TVChartApp: App {
  private let backend = Backend(serverUrl: URL(string: "http://taskmaster.local:8000/shows")!)

  var body: some Scene {
    WindowGroup {
      ContentView(appData: backend.dataSource)
        .onAppear {
          loadInitialData()
        }
    }
  }

  func loadInitialData() {
    Task {
      do {
        try await backend.refetch()
      } catch {
        handleError(error, "initial backend request")
      }
    }
  }
}

