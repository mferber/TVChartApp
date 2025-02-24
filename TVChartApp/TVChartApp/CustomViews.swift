import Foundation
import SwiftUI

/// Toggle that triggers a change handler (`onUserChange`) only when the user clicks,
/// but not when the bound model value has been updated programmatically.
///
/// Example of a case where this might be necessary: the state backing an open view
/// is updated to reflect a different model, causing the Toggle's state to change.
///
/// Specific case in point in this app: EpisodeDetailView, when the user selects a
/// different episode (with the opposite viewed status) while the sheet view is open.
/// We don't want to submit an API update on that kind of change, only when the user
/// specifically took action.
struct UserControlledToggle: View {
  let label: String
  let isOn: Binding<Bool>
  let onUserChange: (Bool) -> Void

  init(_ label: String, isOn: Binding<Bool>, onUserChange: @escaping (Bool) -> Void) {
    self.label = label
    self.isOn = isOn
    self.onUserChange = onUserChange
  }
  
  var body: some View {
    return Toggle(label, isOn: Binding(
      get: { isOn.wrappedValue },
      set: { newValue in
        isOn.wrappedValue = newValue
        onUserChange(newValue)
      }
    ))
  }
}
