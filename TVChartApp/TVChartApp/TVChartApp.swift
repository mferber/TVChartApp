import SwiftUI

@main
struct TVChartApp: App {

  @Observable
  class AppState {
    private(set) var errorDisplayList = ErrorDisplayList()
  }

  private let backend = Backend(baseURL: URL(string: "http://taskmaster.local:8000/")!)
  private let metadataService = MetadataService()

  @State var appState = AppState()

  var body: some Scene {
    WindowGroup {
      ContentView(appData: backend.dataSource, backend: backend, metadataService: metadataService)
        .tint(.accent)
        .showingErrors(from: appState.errorDisplayList)
        .environment(appState)
    }
  }
}

