import Foundation

enum ConnectionError: DisplayableError {
  case loadShowsFailed(cause: Error?)
  case loadShowMetadataFailed(cause: Error?)
  case updateStatusFailed(cause: Error?)

  var description: String {
    switch self {
      case .loadShowsFailed: "Error loading shows"
      case .loadShowMetadataFailed: "Error loading show details"
      case .updateStatusFailed: "Error updating episode status"
    }
  }

  var displayDescription: String { description }
  var displayDetails: String? {
    switch self {
      case .loadShowsFailed(let cause),
          .loadShowMetadataFailed(let cause),
          .updateStatusFailed(let cause):
        cause?.localizedDescription
    }
  }
}

enum BackendError: DisplayableError {
  case noReachableServers

  var displayDescription: String {
    switch self {
      case .noReachableServers:
        "No servers were reachable"
    }
  }

  var displayDetails: String? { nil }
}
