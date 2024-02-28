import Foundation

/// For Error types that are equipped to be displayed in the UI
protocol DisplayableError: Error {
  var displayDescription: String { get }
  var displayDetails: String? { get }
}

/// View model for errors to be displayed
@Observable
class ErrorDisplayList {
  private var items: [ErrorDisplayItem] = []

  init(_ items: [ErrorDisplayItem] = []) {
    self.items = items
  }

  var isEmpty: Bool { items.isEmpty }

  /// Returns a safe copy of the array of items
  var allItems: [ErrorDisplayItem] { items }

  func add(_ e: Error) {
    items.append(ErrorDisplayItem(e))
  }

  func remove(id: UUID) {
    items.removeAll(where: { $0.id == id })
  }
}

/// View model for a single error message
struct ErrorDisplayItem: Identifiable, CustomStringConvertible {
  let id = UUID()
  let description: String
  let details: String?

  init(description: String, details: String? = nil) {
    self.description = description
    self.details = details
  }

  init(_ error: Error) {
    if let error = error as? DisplayableError {
      self.description = error.displayDescription
      self.details = error.displayDetails
    } else {
      self.description = String(describing: error)
      self.details = nil
    }
  }
}

/// Last-ditch minimal error handler
func handleError(_ error: Error, _ annotation: String? = nil) {
  print("Error: \(annotation == nil ? "" : "\(annotation!) - ")\(error)")
}
