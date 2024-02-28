import Foundation
import SwiftUI

// Modifier that installs a pop-down error display interface at the top of the View to which
// it's attached, driven by an ErrorDisplayList maintained somewhere in state; includes
// supporting types and Views

extension View {
  /// Overlays a list of errors, suitable for display, at the top of the modified View
  func showingErrors(from errorList: ErrorDisplayList) -> some View {
    modifier(ShowingErrorsModifier(errorList: errorList))
  }
}

/// Modifier backing `View.showingErrors(from:)`
struct ShowingErrorsModifier: ViewModifier {
  var errorList: ErrorDisplayList

  func body(content: Content) -> some View {
    ZStack {
      content
      if (!errorList.isEmpty) {
        VStack {
          ForEach(errorList.allItems.reversed()) { item in
            ErrorView(item: item, errorList: errorList)
          }
        }
        .background(.accent)
        .frame(maxHeight: .infinity, alignment: .top)
      }
    }
  }
}

/// View displaying a single error message
struct ErrorView: View {
  let item: ErrorDisplayItem
  let errorList: ErrorDisplayList

  var body: some View {
    VStack(spacing: 10) {
      HStack {
        Button {
          withAnimation {
            errorList.remove(id: item.id)
          }
        } label: {
          Image(systemName: "xmark.circle").font(.title)
        }
        Text(String(describing: item)).font(.body).bold()
      }
      .foregroundStyle(.white)
      
      if let details = item.details {
        Text(details).font(.caption).foregroundStyle(.white)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .top)
  }
}

// MARK - Previews

#Preview("Manually created") {
  let errList = ErrorDisplayList([
    ErrorDisplayItem(description: "This is the description", details: "These are the details"),
    ErrorDisplayItem(description: "This is another description", details: "These are more details"),
  ])
  return EmptyView().showingErrors(from: errList)
}

#Preview("From Errors") {
  let errList = ErrorDisplayList([
    ErrorDisplayItem(TVChartError.general("Houston, we've had a problem")),
    ErrorDisplayItem(ConnectionError(kind: .loadShowsFailed, cause: NSError(domain: "test", code: 0)))
  ])
  return EmptyView().showingErrors(from: errList)
}

#Preview("Empty error list") {
  EmptyView().showingErrors(from: ErrorDisplayList([]))
}
