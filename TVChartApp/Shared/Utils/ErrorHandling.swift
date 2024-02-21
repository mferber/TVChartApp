import Foundation

enum TVChartError: Error, CustomStringConvertible {
  case general(_ msg: String?)

  var description: String {
    switch self {
      case .general(let msg): return "General error \(msg == nil ? "" : ": \(msg!)")"
    }
  }
}

func handleError(_ error: Error, _ annotation: String? = nil) {
  print("Error: \(annotation == nil ? "" : "\(annotation!) - ")\(error)")
}
