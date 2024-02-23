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
    dataSource.shows = .loading
    dataSource.shows = .ready(try await client.fetchAllShows().sortedByTitle)
  }

  func updateSeenThru(show: Show) async throws {
    do {
      _ = try await client.patchShowSeenThru(show: show)
    } catch {
      handleError(error)
      try await refetch()  // patch didn't go through, so try to refresh data
    }
  }
}

class BackendStub: BackendProtocol {
  func refetch() async throws { }
  func updateSeenThru(show: Show) async throws { }
}
