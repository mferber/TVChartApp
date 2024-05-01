import Foundation
import SwiftUI

/// Toggle that triggers a change handler (`onUserChange`) only when the user clicks,
/// but not when the bound model value has been updated programmatically.
struct ProgrammaticToggle: View {
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
