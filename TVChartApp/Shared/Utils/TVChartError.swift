import Foundation

/// General app errors
enum TVChartError: DisplayableError {
  
  /// General app error
  case general(_ msg: String?)

  var displayDescription: String {
    switch self {
      case .general(let msg): return "General error\(msg == nil ? "" : ": \(msg!)")"
    }
  }

  var displayDetails: String? { nil }
}
