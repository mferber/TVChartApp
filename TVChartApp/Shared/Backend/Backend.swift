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
    cancellable = requestor.publisher
      .sink(
      receiveCompletion: { _ in },
      receiveValue: { [weak self] shows in
        if let shows {
          self?.dataSource.shows = .ready(shows.sortedByTitle)
        } else {
          self?.dataSource.shows = .loading
        }
      }
    )
    requestor.start()
  }
}
