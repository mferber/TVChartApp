import Foundation

struct ConnectionError: DisplayableError {
  enum Kind {
    case loadShowsFailed
    case loadShowMetadataFailed
    case updateWatchedFailed

    var description: String {
      switch self {
        case .loadShowsFailed: "Error loading shows"
        case .loadShowMetadataFailed: "Error loading show details"
        case .updateWatchedFailed: "Error sending update"
      }
    }
  }

  let kind: Kind
  let cause: Error

  var displayDescription: String { kind.description }
  var displayDetails: String? { cause.localizedDescription }
}
