import SwiftUI

@main
struct TVChartApp: App {
  private let backend = Backend(baseURL: URL(string: "http://taskmaster.local:8000/")!)
  private let metadataService = MetadataService()

  static let tintColor = Color.red

  var body: some Scene {
    WindowGroup {
      ContentView(appData: backend.dataSource, backend: backend, metadataService: metadataService)
        .tint(Self.tintColor)
        .task { await loadShowListings() }
        .refreshable { await loadShowListings() }
    }
  }

  func loadShowListings() async {
    do {
      try await backend.refetch()
    } catch {
      handleError(error, "initial backend request")
    }
  }
}

