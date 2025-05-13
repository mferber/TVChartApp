import SwiftUI


#if DEV_SERVER

private let serverURLs = [ "http://localhost:8000/v0.1/" ]

#else

private let serverURLs = [
  "http://taskmaster.local:8000/v0.1/",  // internal hostname
  "http://73.17.150.67:8000/v0.1/"  // external address via port forwarding
]
//private let serverURLs = [ "http://192.168.0.220/", "http://192.168.0.221/" ]  // invalid: for failure testing

#endif


@main
struct TVChartApp: App {

  @Observable
  class AppState {
    private(set) var errorDisplayList = ErrorDisplayList()
    var pendingToasts: [ToastItem] = []

    func showToast(message: String) {
      pendingToasts.append(ToastItem(message: message, id: UUID()))
    }
  }

  @State private var commandExecutor = CommandExecutor(
    backend: Backend(baseURLs: serverURLs.map { URL(string: $0)! }),
    metadataService: MetadataService()
  )

  @State private var appState = AppState()

  var body: some Scene {
    WindowGroup {
      ContentView(commandExecutor: commandExecutor)
        .tint(.accent)
        .showingErrors(from: appState.errorDisplayList)
        .overlay {
          Toast(pendingToasts: $appState.pendingToasts)
        }
        .environment(appState)
    }
  }
}
