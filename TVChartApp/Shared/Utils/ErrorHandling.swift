import Foundation

func handleError(_ error: Error, _ annotation: String? = nil) {
  print("Error: \(annotation == nil ? "" : "\(annotation!) - ")\(error)")
}
