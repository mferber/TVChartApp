import Foundation
import SwiftUI
import Combine

class Backend {
  
  // main SwiftUI observable
  let dataSource: AppData
  
  private var requestor: BackendClient

  init(serverUrl: URL) {
    dataSource = AppData()
    requestor = BackendClient(serverUrl: serverUrl)
  }

  func refetch() async throws {
    dataSource.shows = .loading
    dataSource.shows = .ready(try await requestor.fetchListings().sortedByTitle)
  }
}
