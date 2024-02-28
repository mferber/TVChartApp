import Foundation
import SwiftUI
import Combine

protocol BackendProtocol {
  func refetch() async throws
  func updateSeenThru(show: Show) async throws
}

class Backend: BackendProtocol {

  // main SwiftUI observable
  let dataSource: AppData
  
  private var client: BackendClient

  init(baseURL: URL) {
    dataSource = AppData()
    client = BackendClient(baseURL: baseURL)

    dataSource.shows = .loading
  }

  func refetch() async throws {
    switch dataSource.shows {
      case .ready: break  // don't show main spinner if we've already loaded
      default: dataSource.shows = .loading
    }

    dataSource.shows = .ready(try await client.fetchAllShows().sortedByTitle)
  }

  func updateSeenThru(show: Show) async throws {
    do {
      _ = try await client.patchShowSeenThru(show: show)
    } catch {
      Task {
        try await refetch()  // patch didn't go through; try to refresh data
      }
      throw error  // ... and rethrow anyway
    }
  }
}

class BackendStub: BackendProtocol {
  func refetch() async throws { }
  func updateSeenThru(show: Show) async throws { }
}
