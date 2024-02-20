import Foundation
import SwiftUI
import Combine

class Backend {
  
  // main SwiftUI observable
  let dataSource: AppData
  
  private var requestor: BackendRequestor
  private var cancellable: AnyCancellable?

  init(serverUrl: URL) {
    dataSource = AppData()
    requestor = BackendRequestor(serverUrl: serverUrl)
  }

  func refetch() async throws {
    dataSource.shows = .loading
    dataSource.shows = .ready(try await requestor.fetchListings())
  }
}
