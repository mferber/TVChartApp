import Foundation
import Combine

class BackendRequestor {
  var publisher: AnyPublisher<[Show]?, Error> {
    subject.eraseToAnyPublisher()
  }

  private let serverUrl: URL
  private let subject = CurrentValueSubject<[Show]?, Error>(nil)
  private var cancellable: AnyCancellable?

  init(serverUrl: URL) {
    self.serverUrl = serverUrl
  }

  func start() {
    cancellable = URLSession.shared.dataTaskPublisher(for: serverUrl)
      .map(\.data)
      .decode(type: [Show].self, decoder: JSONDecoder())
    // FIXME: hook up directly to subject?
      .map { $0 as [Show]? }
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] shows in
          self?.subject.value = shows
        }
      )
  }
}
