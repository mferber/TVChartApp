import SwiftUI

@main
struct TVChartApp: App {
  private let backend = Backend(baseURL: URL(string: "http://taskmaster.local:8000/")!)
  private let metadataService = MetadataService()

  var body: some Scene {
    WindowGroup {
      ContentView(appData: backend.dataSource, backend: backend, metadataService: metadataService)
        .tint(.accent)
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

