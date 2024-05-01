import SwiftUI

#if DEV_SERVER
fileprivate let serverUrl = "http://localhost:8000/v0.1/"
#else
fileprivate let serverUrl = "http://taskmaster.local:8000/v0.1/"
#endif

@main
struct TVChartApp: App {

  @Observable
  class AppState {
    private(set) var errorDisplayList = ErrorDisplayList()
  }

  private let commandExecutor = CommandExecutor(backend: Backend(baseURL: URL(string: serverUrl)!))
  private let metadataService = MetadataService()

  @State var appState = AppState()

  var body: some Scene {
    WindowGroup {
      ContentView(commandExecutor: commandExecutor, metadataService: metadataService)
        .tint(.accent)
        .showingErrors(from: appState.errorDisplayList)
        .environment(appState)
    }
  }
}
